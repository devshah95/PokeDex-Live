resource "aws_security_group" "rds" {
  name   = "pokeshop-${var.env}-${var.service}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
    description     = "PostgreSQL from EKS nodes only - never from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "pokeshop-${var.env}-${var.service}"
  subnet_ids = var.private_subnet_ids
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>?"
}

resource "aws_db_instance" "main" {
  identifier             = "pokeshop-${var.env}-${var.service}"
  engine                 = "postgres"
  engine_version         = "16.6"
  instance_class         = var.instance_class

  db_name                = "pokeshop_${var.service}"
  username               = "pokeshop_${var.service}_${var.env}"
  password               = random_password.db.result

  storage_type           = "gp3"
  allocated_storage      = 20

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible    = false
  storage_encrypted      = true
  multi_az               = var.multi_az
  skip_final_snapshot    = true
}