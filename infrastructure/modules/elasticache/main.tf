resource "aws_security_group" "redis" {
  name   = "pokeshop-${var.env}-redis-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_subnet_group" "main" {
  name       = "pokeshop-${var.env}-redis"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "pokeshop-${var.env}"
  description                = "PokéShop Redis ${var.env}"
  node_type                  = var.node_type
  num_cache_clusters         = var.env == "prod" ? 2 : 1
  automatic_failover_enabled = var.env == "prod"
  engine_version             = "7.1"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
}