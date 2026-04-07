variable "env" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_node_sg_id" { type = string }
variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}