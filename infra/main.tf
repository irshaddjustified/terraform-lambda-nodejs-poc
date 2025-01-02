terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2" # Sydney region
}

# Lambda function definition
resource "aws_lambda_function" "healthcheck" {
  function_name = "healthcheck-api"
  runtime       = "nodejs22.x"
  handler       = "lambda.handler"
  filename      = "${path.module}/healthcheck.zip"

  source_code_hash = filebase64sha256("${path.module}/healthcheck.zip")
  role             = aws_iam_role.lambda_exec.arn

  tags = {
    terraform = "true"
    createdBy = "Irshad"
  }
}

# API Gateway Rest API
resource "aws_api_gateway_rest_api" "healthcheck_api" {
  name = "HealthCheckAPI"

  tags = {
    terraform = "true"
    createdBy = "Irshad"
  }
}

# API Gateway resource (tags removed because it's unsupported)
resource "aws_api_gateway_resource" "healthcheck_resource" {
  rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
  parent_id   = aws_api_gateway_rest_api.healthcheck_api.root_resource_id
  path_part   = "healthcheck"
}

# API Gateway Method
resource "aws_api_gateway_method" "healthcheck_method" {
  rest_api_id   = aws_api_gateway_rest_api.healthcheck_api.id
  resource_id   = aws_api_gateway_resource.healthcheck_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "healthcheck_integration" {
  rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
  resource_id = aws_api_gateway_resource.healthcheck_resource.id
  http_method = aws_api_gateway_method.healthcheck_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.healthcheck.invoke_arn
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.healthcheck.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.healthcheck_api.execution_arn}/*"
}

# API Gateway Deployment (tags removed because they're unsupported)
resource "aws_api_gateway_deployment" "healthcheck_deployment" {
  depends_on  = [aws_api_gateway_integration.healthcheck_integration]
  rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
}

# API Gateway Stage
resource "aws_api_gateway_stage" "healthcheck_stage" {
  deployment_id = aws_api_gateway_deployment.healthcheck_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.healthcheck_api.id
  stage_name    = "dev"

  tags = {
    terraform = "true"
    createdBy = "Irshad"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    terraform = "true"
    createdBy = "Irshad"
  }
}

# Attach Basic Execution Role to IAM Role
resource "aws_iam_policy_attachment" "lambda_policy_attach" {
  name       = "lambda_policy_attach"
  roles      = [aws_iam_role.lambda_exec.name] # Attach only to the Lambda execution role
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
