resource "aws_ecr_repository" "ecr_repo" {
  for_each = toset(var.ecr_repositories)
  name     = "${each.value}/${var.env}"
}

resource "aws_iam_user" "ecr_user" {
  name = "${var.name}-${var.env}-ecr-user"
}

resource "aws_iam_user_policy" "ecr_user_policy" {
  name = "ecr-user-policy"
  user = aws_iam_user.ecr_user.name

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage"
          ],
          "Resource": "*"
        }
      ]
    }
  EOF
}
