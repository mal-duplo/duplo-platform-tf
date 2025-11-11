############################################################
# GitHub OIDC → IAM Role for Terraform (duplo-platform-tf)
# Account: 359100918503 | Region: us-east-1
############################################################

# 1) GitHub OIDC provider (create only if you don't already have one)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC root CA
}

# 2) Trust policy: aud + sub (required), optionally repository/ref
data "aws_iam_policy_document" "gh_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Required: OIDC audience
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # REQUIRED BY AWS: scope the 'sub' claim (repo + ref)
    # Allow only this repo on the main branch
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:mal-duplo/duplo-platform-tf:ref:refs/heads/main",
        # Optional additions you may want later:
        # "repo:mal-duplo/duplo-platform-tf:pull_request",
        # "repo:mal-duplo/duplo-platform-tf:ref:refs/heads/development",
        # "repo:mal-duplo/duplo-platform-tf:ref:refs/tags/*",
      ]
    }

    # (Optional) extra clarity — you can keep these or remove them.
    # condition {
    #   test     = "StringEquals"
    #   variable = "token.actions.githubusercontent.com:repository"
    #   values   = ["mal-duplo/duplo-platform-tf"]
    # }
    # condition {
    #   test     = "StringEquals"
    #   variable = "token.actions.githubusercontent.com:ref"
    #   values   = ["refs/heads/main"]
    # }

    # (Optional) harden by environment:
    # condition {
    #   test     = "StringEquals"
    #   variable = "token.actions.githubusercontent.com:environment"
    #   values   = ["tenant1"]
    # }
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
      "arn:aws:kms:us-east-1:359100918503:key/8277ea5a-e952-4ed1-8ae7-31bc14e38195"
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
    resources = ["*"] # tighten to your nodegroup/fargate/cluster role ARNs later
    # Optional:
    # condition {
    #   test     = "StringEquals"
    #   variable = "iam:PassedToService"
    #   values   = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    # }
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