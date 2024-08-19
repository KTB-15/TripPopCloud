resource "aws_db_subnet_group" "main" {
  name       = "main_subnet_group"
  subnet_ids = [
    aws_subnet.private_subnet_be.id,  # ap-northeast-2a
    aws_subnet.private_subnet_db.id,  # ap-northeast-2c
  ]

  tags = {
    Name = "main_subnet_group"
  }
}

resource "aws_db_instance" "postgresql" {
  allocated_storage    = 20
  max_allocated_storage = 50
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "masteruser"
  password             = var.db_password
  parameter_group_name = "default.postgres16"
  skip_final_snapshot  = true
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "terraform-rds-postgresql"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "allow_postgres"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_be.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
