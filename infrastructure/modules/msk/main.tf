resource "aws_security_group" "msk" {
  name   = "pokeshop-${var.env}-msk-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 9092
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_msk_configuration" "main" {
  name            = "pokeshop-${var.env}"
  kafka_versions  = ["3.5.1"]

  server_properties = <<-EOT
    auto.create.topics.enable=true
    default.replication.factor=2
    min.insync.replicas=1
    num.partitions=3
    log.retention.hours=168
  EOT
}

resource "aws_msk_cluster" "main" {
  cluster_name           = "pokeshop-${var.env}"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = var.env == "prod" ? 3 : 2

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = slice(var.private_subnet_ids, 0, var.env == "prod" ? 3 : 2)
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = 20
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }
}