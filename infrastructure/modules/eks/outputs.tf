output "cluster_name"           { value = aws_eks_cluster.main.name }
output "cluster_endpoint"       { value = aws_eks_cluster.main.endpoint }
output "oidc_issuer"            { value = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://") }
output "node_security_group_id" { value = aws_eks_node_group.main.resources[0].remote_access_security_group_id }