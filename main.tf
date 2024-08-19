provider "aws" {
  region = "ap-northeast-2"  # 사용하고자 하는 AWS 리전
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main_igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2a"

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet_be" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"  # BE는 ap-northeast-2a에 위치

  tags = {
    Name = "private_subnet_be"
  }
}

resource "aws_subnet" "private_subnet_db" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2c"  # DB는 ap-northeast-2c에 위치

  tags = {
    Name = "private_subnet_db"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat_gw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc" # 원래 vpc = true 였는데 오류나서 수정
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rt_assoc_be" {
  subnet_id      = aws_subnet.private_subnet_be.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_assoc_db" {
  subnet_id      = aws_subnet.private_subnet_db.id
  route_table_id = aws_route_table.private_rt.id
}

# 공용 보안 그룹 추가
resource "aws_security_group" "common_sg" {
  name        = "common_sg"
  description = "Allow HTTP, HTTPS, and SSH traffic, and internal VPC communication"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP 트래픽을 모든 IP에서 허용
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS 트래픽을 모든 IP에서 허용
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH 트래픽을 모든 IP에서 허용
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC 내부 트래픽을 허용 (프론트엔드 <-> 백엔드 통신)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # 모든 아웃바운드 트래픽 허용
  }

  tags = {
    Name = "common_sg"
  }
}

variable "db_password" {
  description = "The password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true  # Terraform 출력에서 비밀번호 숨기기
}

# 프론트엔드 인스턴스에 보안 그룹 연결
resource "aws_instance" "frontend" {
  ami           = "ami-062cf18d655c0b1e8"  # 원하는 AMI로 대체 (ubuntu)
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "trip-key" # 프로젝트 .pem 키로 변경

  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "frontend_server"
  }
}

# 백엔드 인스턴스에 보안 그룹 연결
resource "aws_instance" "backend" {
  ami           = "ami-062cf18d655c0b1e8"  # 원하는 AMI로 대체 (ubuntu)
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_subnet_be.id
  key_name      = "trip-key"

  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "backend_server"
  }
}
