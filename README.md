# Terraform-to-automate-AWS-Lambda-and-CloudWatch.


--------------------
Terraform Code

1. IAM Role
2. Lambda function
3. Cloudwatch role
--------------
---STEPS------
--
Step1: We will start with the customary provider block, which will define that we are using AWS and region as us-west-2.

provider "aws" {
  region = "us-west-2"
}
--
Step2: Create an IAM Role
--
resource "aws_iam_role" "lambda-role" {
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

resource "aws_iam_policy" "lambda-policy" {
  name = "lambda-ec2-stop-start"

  policy = jsonencode({
    Version = "2012-10-17"
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-ec2-policy-attach" {
  policy_arn = aws_iam_policy.lambda-policy.arn
  role = aws_iam_role.lambda-role.name
}
--
Step3: First zip the lambda function we wrote on Day 23

zip lambda.zip lambda.py    
adding: lambda.py
--
Using aws_lambda_function resource, create lambda function

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
filename: Is the name of the file, you zipped in the previous step
function name: Is the name of the function you defined in your python code
role: IAM role attached to the Lambda Function. This governs both who / what can invoke your Lambda Function, as well as what resources our Lambda Function has access to
handler: Function entry point in our code(python code filename.method name) (filename: lambda.py we don’t need to include file extension) and (lambda function is lambda_handler def lambda_handler(event, context))
source_code_hash: Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3_key. The usual way to set this is filebase64sha256("file.zip") (Terraform 0.11.12 and later) or base64sha256(file("file.zip")) (Terraform 0.11.11 and earlier), Where “file.zip” is the local filename of the lambda function source archive.
Runtime: The identifier of the function’s runtime, which is python3.7 in this case.
timeout: timeout for the lambda function(default is 3 sec)
--
Step4: Create CloudWatch Event rule and allow CloudWatch to execute Lambda function

resource "aws_cloudwatch_event_rule" "ec2-rule" {
  name        = "ec2-rule"
  description = "Trigger Stop Instance every 5 min"
  schedule_expression = "rate(5 minutes)"
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
--
