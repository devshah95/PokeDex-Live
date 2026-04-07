variable "env"                    { type = string }
variable "auth_db_endpoint"       { type = string }
variable "auth_db_username"       { type = string }
variable "auth_db_password"       { 
    type = string
    sensitive = true 
 }
variable "pokemon_db_endpoint"    { type = string }
variable "pokemon_db_username"    { type = string }
variable "pokemon_db_password"    { 
    type = string
    sensitive = true 
 }
variable "favorites_db_endpoint"  { type = string }
variable "favorites_db_username"  { type = string }
variable "favorites_db_password"  { 
    type = string 
    sensitive = true 
    }
variable "redis_endpoint"         { type = string }
variable "kafka_brokers"          { type = string }