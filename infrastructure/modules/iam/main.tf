data "aws_caller_identity" "current" {}

resource "aws_iam_role" "pod_role" {
  name = "pokeshop-${var.env}-pod-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_issuer}" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_issuer}:sub" = "system:serviceaccount:pokeshop-${var.env}:pokeshop-sa"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "pod_permissions" {
  name = "pokeshop-${var.env}-pod-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:*:*:secret:pokeshop/${var.env}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pod" {
  role       = aws_iam_role.pod_role.name
  policy_arn = aws_iam_policy.pod_permissions.arn
}