output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_issuer" {
  value = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  value = aws_eks_node_group.main.resources[0].remote_access_security_group_id
}