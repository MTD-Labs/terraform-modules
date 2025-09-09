# # locals {
# #   repository_name = split("/", var.lambda_image_url)[1]
# # }

# # data "aws_ecr_image" "latest_image" {
# #   repository_name = local.repository_name
# #   image_tag       = "latest"
# # }

# resource "aws_lambda_function" "image_resize" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0

#   provider = aws.main ### lambda@edge requires us-east-1 region

#   package_type  = "Image"
#   function_name = "${var.env}-image-resize"
#   # handler          = "index.handler"
#   # runtime          = "nodejs20.x"
#   image_uri = "${var.lambda_image_url}@${data.aws_ecr_image.latest_image.image_digest}"
#   role      = aws_iam_role.lambda_exec_role[count.index].arn
#   # publish          = true
#   # timeout          = 15
#   publish     = true
#   memory_size = var.lambda_memory_size
#   vpc_config {
#     subnet_ids         = var.lambda_private_subnets
#     security_group_ids = var.lambda_security_group
#   }

# }

# resource "aws_iam_role" "lambda_exec_role" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0

#   name = "${var.env}_lambda_exec_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       },
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       },
#     ]
#   })
# }

# resource "aws_iam_policy" "lambda_exec_policy" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0

#   name = "${var.env}_lambda_exec_policy"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "ssm:GetParameter"
#         ],
#         Resource = "arn:aws:ssm:${var.lambda_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.env}-${var.name}-*"
#       },
#       {
#         Effect   = "Deny",
#         Action   = "ssm:GetParameter",
#         Resource = "arn:aws:ssm:*:*:parameter/admin-*"
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ],
#         Resource = "arn:aws:logs:${var.lambda_region}:*:log-group:/aws/lambda/*:*"
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:PutObject",
#           "s3:GetObject"
#         ],
#         Resource = [
#           "arn:aws:s3:::${var.cdn_buckets[0].name}/*"
#         ]
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "ec2:CreateNetworkInterface",
#           "ec2:DescribeNetworkInterfaces",
#           "ec2:DeleteNetworkInterface"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }


# resource "aws_iam_role_policy_attachment" "lambda_exec_attach" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0

#   policy_arn = aws_iam_policy.lambda_exec_policy[count.index].arn
#   role       = aws_iam_role.lambda_exec_role[count.index].name
# }

# resource "aws_lambda_function_url" "image_resize_url" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0
#   function_name      = aws_lambda_function.image_resize[count.index].function_name
#   authorization_type = "NONE"

#   cors {
#     allow_origins = ["*"]
#     allow_methods = ["*"]
#   }
# }

# resource "aws_lambda_permission" "allow_cloudfront" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0
#   statement_id  = "AllowCloudFrontInvoke"
#   action        = "lambda:InvokeFunctionUrl"
#   function_name = aws_lambda_function.image_resize[count.index].function_name
#   principal     = "*"
#   source_arn    = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.default[0].id}"

#   # Explicit condition for public access when the authorization type is NONE
#   function_url_auth_type = "NONE"
# }
