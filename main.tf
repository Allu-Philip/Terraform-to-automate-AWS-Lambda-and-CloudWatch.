terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.28.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

#Creating IAM Role

resource "aws_iam_role" "lambda-role" {
  name = "ec2-stop-start"
  #terraform's jsoncode function converts
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "lambda-ec2-role"
  }
}

#Creating IAM policy

resource "aws_iam_policy" "lambda-policy" {
  name = "lambda-ec2-stop-start"

  policy = jsonencode({
    Version = "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ],
        "Resource" : "*"
      }
    ]
  })
}

#Attaching iamrole with policy

resource "aws_iam_role_policy_attachment" "lambda-ec2-policy-attach" {
  role       = aws_iam_role.lambda-role.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}

#End Of IAM

#Start Of Lambda function

resource "aws_lambda_function" "ec2-stop-start" {
  filename      = "lambda.zip"
  function_name = "lambda"
  role          = aws_iam_role.lambda-role.arn
  handler       = "lambda.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda.zip")

  runtime = "python3.7"
  timeout = 63
}

#Cloudwatch Event Rule

resource "aws_cloudwatch_event_rule" "ec2-rule" {
  name                = "ec2-rule"
  description         = "Trigger EC@ instance stop every 1 min"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda-func" {
  rule      = aws_cloudwatch_event_rule.ec2-rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.ec2-stop-start.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2-stop-start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2-rule.arn
}
