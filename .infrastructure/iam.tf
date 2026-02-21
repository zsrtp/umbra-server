# GHA OIDC role
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "gha" {
  name = "gha-role-umbra-server"
  tags = local.iac_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" = "repo:zsrtp/umbra-server:ref:refs/heads/main"
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  inline_policy {
    name = "deploy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "Global"
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken",
            "sts:GetCallerIdentity",
          ]
          Resource = "*"
        },
        {
          Sid    = "ECR"
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:CompleteLayerUpload",
            "ecr:DescribeRepositories",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetLifecyclePolicy",
            "ecr:GetRepositoryPolicy",
            "ecr:InitiateLayerUpload",
            "ecr:ListTagsForResource",
            "ecr:PutImage",
            "ecr:PutLifecyclePolicy",
            "ecr:TagResource",
            "ecr:UploadLayerPart",
          ]
          Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/umbra-server"
        },
        {
          Sid    = "EC2Read"
          Effect = "Allow"
          Action = "ec2:Describe*"
          Resource = "*"
        },
        {
          Sid    = "EC2Write"
          Effect = "Allow"
          Action = [
            "ec2:RunInstances",
            "ec2:TerminateInstances",
            "ec2:CreateSecurityGroup",
            "ec2:DeleteSecurityGroup",
            "ec2:AuthorizeSecurityGroup*",
            "ec2:RevokeSecurityGroup*",
            "ec2:AllocateAddress",
            "ec2:ReleaseAddress",
            "ec2:AssociateAddress",
            "ec2:DisassociateAddress",
            "ec2:CreateTags",
            "ec2:ModifyInstanceAttribute",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "aws:ResourceTag/iac_type" = "umbra-server"
            }
          }
        },
        {
          Sid    = "EC2RunInstances"
          Effect = "Allow"
          Action = [
            "ec2:RunInstances",
            "ec2:CreateTags",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "aws:RequestTag/iac_type" = "umbra-server"
            }
          }
        },
        {
          Sid    = "EC2RunInstancesDeps"
          Effect = "Allow"
          Action = "ec2:RunInstances"
          Resource = [
            "arn:aws:ec2:${var.aws_region}::image/*",
            "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
            "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*",
            "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*",
            "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:volume/*",
          ]
        },
        {
          Sid    = "IAMRoles"
          Effect = "Allow"
          Action = [
            "iam:GetRole",
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:TagRole",
            "iam:PassRole",
            "iam:GetRolePolicy",
            "iam:PutRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:ListRolePolicies",
            "iam:ListAttachedRolePolicies",
            "iam:AttachRolePolicy",
            "iam:DetachRolePolicy",
            "iam:ListInstanceProfilesForRole",
          ]
          Resource = [
            "arn:aws:iam::${var.aws_account_id}:role/umbra-server-*",
            "arn:aws:iam::${var.aws_account_id}:role/gha-role-umbra-server",
          ]
        },
        {
          Sid    = "IAMInstanceProfile"
          Effect = "Allow"
          Action = [
            "iam:GetInstanceProfile",
            "iam:CreateInstanceProfile",
            "iam:DeleteInstanceProfile",
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:TagInstanceProfile",
          ]
          Resource = "arn:aws:iam::${var.aws_account_id}:instance-profile/umbra-server"
        },
        {
          Sid    = "IAMRead"
          Effect = "Allow"
          Action = [
            "iam:GetPolicy",
            "iam:GetOpenIDConnectProvider",
            "iam:ListOpenIDConnectProviders",
          ]
          Resource = "*"
        },
        {
          Sid    = "SSMSendCommand"
          Effect = "Allow"
          Action = "ssm:SendCommand"
          Resource = "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
        },
        {
          Sid    = "SSMSendCommandInstances"
          Effect = "Allow"
          Action = "ssm:SendCommand"
          Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*"
          Condition = {
            StringEquals = {
              "ssm:resourceTag/iac_type" = "umbra-server"
            }
          }
        },
        {
          Sid    = "SSMGetInvocation"
          Effect = "Allow"
          Action = "ssm:GetCommandInvocation"
          Resource = "*"
        },
        {
          Sid    = "TerraformState"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket",
          ]
          Resource = [
            "arn:aws:s3:::${var.tf_state_bucket}",
            "arn:aws:s3:::${var.tf_state_bucket}/umbra-server.tfstate",
          ]
        },
      ]
    })
  }
}

# EC2 instance profile
resource "aws_iam_role" "ec2" {
  name = "umbra-server-ec2"
  tags = local.iac_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_iam_instance_profile" "umbra" {
  name = "umbra-server"
  role = aws_iam_role.ec2.name
  tags = local.iac_tags
}
