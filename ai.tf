# AI 서버 인스턴스에 보안 그룹 연결
resource "aws_instance" "ai_server" {
  ami           = "ami-062cf18d655c0b1e8"  # 원하는 AMI로 대체 (ubuntu)
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_subnet_be.id
  key_name      = "trip-key"

  vpc_security_group_ids = [aws_security_group.common_sg.id]

  tags = {
    Name = "ai_server"
  }
}