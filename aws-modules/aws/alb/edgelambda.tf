resource "local_file" "lambda_function_edge" {
  count = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0

  content = templatefile(
    "${path.module}/image-resize/index.js.tmpl",
    {
      env                   = var.env
      name                  = var.name
      lambda_bucket_name    = var.lambda_bucket_name
      ssm_secret_key        = var.ssm_secret_key
      document_data_api_url = var.document_data_api_url
      html_to_pdf_url       = var.html_to_pdf_url
      html_to_docx_url      = var.html_to_docx_url
    }
  )
  filename = "${path.module}/image-resize/index.js"
}

data "archive_file" "lambda_function_edge" {
  count       = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/image-resize"
  output_path = "image-resize.zip"
  depends_on  = [local_file.lambda_function_edge]
}

resource "aws_lambda_function" "image_resize_edge" {
  count = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0

  provider = aws.us_east_1 ### Lambda@Edge requires us-east-1 region

  function_name    = "image-resize"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda_function_edge[0].output_path
  source_code_hash = data.archive_file.lambda_function_edge[0].output_base64sha256
  role             = aws_iam_role.lambda_exec_role_edge[count.index].arn
  publish          = true
  timeout          = 15
}

resource "aws_iam_role" "lambda_exec_role_edge" {
  count = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0

  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "edgelambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_policy_edge" {
  count = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0

  name = "lambda_exec_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${var.lambda_region}:*:log-group:/aws/lambda/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.lambda_region}:*:log-group:/aws/lambda/*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:Describe*",
          "ssm:List*"
        ]
        Resource = "arn:aws:ssm:${var.lambda_region}:*:parameter/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:Get*"
        ]
        Resource = "arn:aws:ssm:${var.lambda_region}:*:parameter/${var.env}-${var.name}-image-resize-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*Object"
        ]
        Resource = "arn:aws:s3:::${var.env}-${var.name}-*/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attach_edge" {
  count = var.cdn_optimize_images && var.lambda_edge_enabled ? 1 : 0

  policy_arn = aws_iam_policy.lambda_exec_policy_edge[count.index].arn
  role       = aws_iam_role.lambda_exec_role_edge[count.index].name
}
