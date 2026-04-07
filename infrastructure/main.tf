terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }

  backend "s3" {
    bucket       = "pokeshop-tfstate-704225640908"
    key          = "pokeshop/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Project   = "PokéDexLive"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  services = ["auth", "pokemon", "favorites"]
}

# ── VPC ────────────────────────────────────────────────────────────────────
module "vpc" {
  source     = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
}

# ── EKS ────────────────────────────────────────────────────────────────────
module "eks" {
  source             = "./modules/eks"
  private_subnet_ids = module.vpc.private_subnet_ids
}

# ── BASTION HOST ───────────────────────────────────────────────────────────
resource "aws_key_pair" "bastion" {
  key_name   = "pokeshop-bastion"
  public_key = file(pathexpand("~/.ssh/pokeshop-bastion.pub"))
}

resource "aws_security_group" "bastion" {
  name        = "pokeshop-bastion-sg"
  description = "SSH access to bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["136.30.130.182/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = {
    Name = "pokeshop-bastion"
  }
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

# ── RDS — 6 instances (3 services × 2 environments) ───────────────────────
module "rds_dev" {
  for_each = toset(local.services)
  source   = "./modules/rds"

  env                = "dev"
  service            = each.value
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  instance_class     = "db.t3.micro"
  multi_az           = false
}

module "rds_prod" {
  for_each = toset(local.services)
  source   = "./modules/rds"

  env                = "prod"
  service            = each.value
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  instance_class     = "db.t3.small"
  multi_az           = true
}

# ── ELASTICACHE REDIS ──────────────────────────────────────────────────────
module "redis_dev" {
  source = "./modules/elasticache"

  env                = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  node_type          = "cache.t3.micro"
}

module "redis_prod" {
  source = "./modules/elasticache"

  env                = "prod"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  node_type          = "cache.t3.small"
}

# ── MSK KAFKA ──────────────────────────────────────────────────────────────
module "kafka_dev" {
  source = "./modules/msk"

  env                = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
}

module "kafka_prod" {
  source = "./modules/msk"

  env                = "prod"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
}

# ── S3 ─────────────────────────────────────────────────────────────────────
module "s3_dev" {
  source = "./modules/s3"

  env        = "dev"
  account_id = data.aws_caller_identity.current.account_id
}

module "s3_prod" {
  source = "./modules/s3"

  env        = "prod"
  account_id = data.aws_caller_identity.current.account_id
}

# ── IAM / IRSA ─────────────────────────────────────────────────────────────
module "iam_dev" {
  source = "./modules/iam"

  env          = "dev"
  oidc_issuer  = module.eks.oidc_issuer
  s3_bucket_arn = module.s3_dev.bucket_arn
}

module "iam_prod" {
  source = "./modules/iam"

  env          = "prod"
  oidc_issuer  = module.eks.oidc_issuer
  s3_bucket_arn = module.s3_prod.bucket_arn
}

# ── SECRETS MANAGER ────────────────────────────────────────────────────────
module "secrets_dev" {
  source = "./modules/secrets"

  env = "dev"

  auth_db_endpoint      = module.rds_dev["auth"].db_endpoint
  auth_db_username      = module.rds_dev["auth"].db_username
  auth_db_password      = module.rds_dev["auth"].db_password

  pokemon_db_endpoint   = module.rds_dev["pokemon"].db_endpoint
  pokemon_db_username   = module.rds_dev["pokemon"].db_username
  pokemon_db_password   = module.rds_dev["pokemon"].db_password

  favorites_db_endpoint = module.rds_dev["favorites"].db_endpoint
  favorites_db_username = module.rds_dev["favorites"].db_username
  favorites_db_password = module.rds_dev["favorites"].db_password

  redis_endpoint        = module.redis_dev.redis_endpoint
  kafka_brokers         = module.kafka_dev.bootstrap_brokers
}

module "secrets_prod" {
  source = "./modules/secrets"

  env = "prod"

  auth_db_endpoint      = module.rds_prod["auth"].db_endpoint
  auth_db_username      = module.rds_prod["auth"].db_username
  auth_db_password      = module.rds_prod["auth"].db_password

  pokemon_db_endpoint   = module.rds_prod["pokemon"].db_endpoint
  pokemon_db_username   = module.rds_prod["pokemon"].db_username
  pokemon_db_password   = module.rds_prod["pokemon"].db_password

  favorites_db_endpoint = module.rds_prod["favorites"].db_endpoint
  favorites_db_username = module.rds_prod["favorites"].db_username
  favorites_db_password = module.rds_prod["favorites"].db_password

  redis_endpoint        = module.redis_prod.redis_endpoint
  kafka_brokers         = module.kafka_prod.bootstrap_brokers
}

# ── ROUTE 53 + ACM (must come before ALB HTTPS listener wiring) ───────────
module "route53" {
  source = "./modules/route53"

  # IMPORTANT:
  # This creates the ACM cert and validates it via Route53.
  # It ALSO creates the alias records pointing at the ALB.
  # Because it needs ALB DNS + zone ID, there is an implicit dependency on module.alb.
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

# ── ALB ────────────────────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  acm_cert_arn      = module.route53.cert_arn
}