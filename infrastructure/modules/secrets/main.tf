locals {
  services = ["auth", "pokemon", "favorites"]
}

resource "aws_secretsmanager_secret" "db" {
  for_each = toset(local.services)
  name     = "pokeshop/${var.env}/${each.value}-db"
}

resource "aws_secretsmanager_secret_version" "db_auth" {
  secret_id = aws_secretsmanager_secret.db["auth"].id

  secret_string = jsonencode({
    host     = var.auth_db_endpoint
    port     = 5432
    dbname   = "pokeshop_auth"
    username = var.auth_db_username
    password = var.auth_db_password
  })
}

resource "aws_secretsmanager_secret_version" "db_pokemon" {
  secret_id = aws_secretsmanager_secret.db["pokemon"].id

  secret_string = jsonencode({
    host     = var.pokemon_db_endpoint
    port     = 5432
    dbname   = "pokeshop_pokemon"
    username = var.pokemon_db_username
    password = var.pokemon_db_password
  })
}

resource "aws_secretsmanager_secret_version" "db_favorites" {
  secret_id = aws_secretsmanager_secret.db["favorites"].id

  secret_string = jsonencode({
    host     = var.favorites_db_endpoint
    port     = 5432
    dbname   = "pokeshop_favorites"
    username = var.favorites_db_username
    password = var.favorites_db_password
  })
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name = "pokeshop/${var.env}/jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id

  secret_string = jsonencode({
    secret = random_password.jwt.result
  })
}

resource "aws_secretsmanager_secret" "redis" {
  name = "pokeshop/${var.env}/redis"
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id

  secret_string = jsonencode({
    host = var.redis_endpoint
    port = 6379
  })
}

resource "aws_secretsmanager_secret" "kafka" {
  name = "pokeshop/${var.env}/kafka"
}

resource "aws_secretsmanager_secret_version" "kafka" {
  secret_id = aws_secretsmanager_secret.kafka.id

  secret_string = jsonencode({
    brokers = var.kafka_brokers
  })
}