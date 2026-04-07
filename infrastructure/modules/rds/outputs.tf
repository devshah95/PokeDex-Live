output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_username" {
  value = aws_db_instance.main.username
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "db_name" {
  value = aws_db_instance.main.db_name
}