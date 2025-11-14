############################################################
# GitHub OIDC → IAM Role for Terraform (duplo-platform-tf)
# Account: 359100918503 | Region: us-east-1
############################################################

# 1) GitHub OIDC provider (create only if you don't already have one)
#    Include both current thumbprints GitHub publishes.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # Old DigiCert root + current Let’s Encrypt ISRG Root X1
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1b511abead59c6ce207077c0bf0e0043b1382612"
  ]
}

# 2) Trust policy: minimal & reliable → aud + sub
#    sub encodes both repository and ref (branch/tag) in one claim.
data "aws_iam_policy_document" "gh_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Must target STS
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope to this repo on main branch (adjust as needed)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:mal-duplo/duplo-platform-tf:ref:refs/heads/main",
        "repo:mal-duplo/duplo-platform-tf:environment:tenant1"
      ]
    }

    # If you want to ALSO allow PRs or tags later, add lines like:
    # values = [
    #   "repo:mal-duplo/duplo-platform-tf:ref:refs/heads/main",
    #   "repo:mal-duplo/duplo-platform-tf:pull_request",       # PRs
    #   "repo:mal-duplo/duplo-platform-tf:ref:refs/tags/*"     # tags
    # ]
  }
}

resource "aws_iam_role" "github_oidc_terraform" {
  name                 = "github-oidc-terraform"
  assume_role_policy   = data.aws_iam_policy_document.gh_oidc_trust.json
  description          = "Terraform via GitHub Actions (OIDC) for mal-duplo/duplo-platform-tf"
  max_session_duration = 3600
  tags = {
    ManagedBy = "Terraform"
    Purpose   = "GitHubActions-Terraform"
  }
}

# 3) Backend access policy (S3/DynamoDB/KMS) for Terraform state
data "aws_iam_policy_document" "tf_backend" {
  statement {
    sid     = "S3StateAccess"
    effect  = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::mal-tfstate-nonprod"
    ]
  }

  statement {
    sid     = "S3ObjectAccess"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      "arn:aws:s3:::mal-tfstate-nonprod/*"
    ]
  }

  statement {
    sid     = "DynamoDBStateLock"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [
      "arn:aws:dynamodb:us-east-1:359100918503:table/tf-locks-nonprod"
    ]
  }

  statement {
    sid     = "KmsForS3Backend"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:kms:us-east-1:359100918503:key/4f465fd5-e497-4485-b0bb-1a43277ab47f"
    ]
  }
}

resource "aws_iam_policy" "tf_backend" {
  name        = "terraform-backend-access"
  description = "Access to S3/DynamoDB/KMS for Terraform backend"
  policy      = data.aws_iam_policy_document.tf_backend.json
}

resource "aws_iam_role_policy_attachment" "attach_backend" {
  role       = aws_iam_role.github_oidc_terraform.name
  policy_arn = aws_iam_policy.tf_backend.arn
}

# 4) Infrastructure permissions (adjust to your modules over time)
data "aws_iam_policy_document" "tf_infra" {
  statement {
    sid    = "Networking"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:Describe*",
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateRoute", "ec2:ReplaceRoute", "ec2:DeleteRoute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
      "ec2:AllocateAddress", "ec2:ReleaseAddress"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EKS"
    effect  = "Allow"
    actions = ["eks:*"]
    resources = ["*"]
  }

  statement {
    sid     = "IamPassRoleForEks"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = ["*"] # tighten later to specific nodegroup/fargate/cluster roles
    # Optional:
    # condition {
    #   test     = "StringEquals"
    #   variable = "iam:PassedToService"
    #   values   = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    # }
  }

  statement {
    sid     = "SsmPublicParameterRead"
    effect  = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DescribeParameters"
    ]
    resources = [
      "arn:aws:ssm:us-east-1::parameter/aws/service/eks/*"
    ]
  }

  statement {
    sid     = "SecretsManagerAll"
    effect  = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "KmsForTenantRdsSecret"
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:kms:us-east-1:359100918503:key/4f465fd5-e497-4485-b0bb-1a43277ab47f"
    ]
  }
}

resource "aws_iam_policy" "tf_infra" {
  name        = "terraform-infra-access"
  description = "Permissions Terraform needs to create infra (scope as required)"
  policy      = data.aws_iam_policy_document.tf_infra.json
}

resource "aws_iam_role_policy_attachment" "attach_infra" {
  role       = aws_iam_role.github_oidc_terraform.name
  policy_arn = aws_iam_policy.tf_infra.arn
}

# Optional output
output "github_oidc_role_arn" {
  value = aws_iam_role.github_oidc_terraform.arn
}