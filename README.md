# Author : Mohamed Irshad

# terraform-lambda-nodejs-poc
poc implementation of a nodejs, express based healthcheck API that uses AWS APIGateway and Lambda where infrastructure is created using terraform


# 1. Set Up a Node.js Project
Steps:
## Initialize the project:

    mkdir healthcheck-api
    cd healthcheck-api
    npm init -y

## Install dependencies:

    npm install express serverless-http
## Create an index.js file and paste the following code:   

    // javascript
    const express = require('express');
    const app = express();

    app.post('/healthcheck', (req, res) => {
        res.status(200).send({ message: 'Hello, World!' });
    });

    // Export the app for Lambda
    module.exports = app;
    
## Create a Lambda Handler named lambda.js as paste the following code:

    // javascript
    const serverless = require('serverless-http');
    const app = require('./index');

    module.exports.handler = serverless(app);

2. Configure AWS Access for Terraform
Steps:
## Log in to AWS Management Console with an account that has permissions to manage IAM.

## Create a user to be used by terraform : name it terraform-user (this may already exist so you can combine your name with it)
## Attach Necessary Policies to the terraform-user:

    Navigate to IAM > Users > terraform-user.
    Attach the following managed policy:
    AdministratorAccess (or equivalent permissions for Lambda, API Gateway, and IAM roles).

## Create additional permission for terraform user to do changes.
    Policy name : tf_attach_detach_pass_role_policy
    If this policy does not exist, create it:

    Navigate to IAM > Policies.
    Click Create Policy, go to the JSON tab, and paste:

        {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Effect": "Allow",
            "Action": [
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PassRole"
            ],
            "Resource": "*"
            }
        ]
        }
        
    Save the policy as tf_attach_detach_pass_role_policy.
    Attach the policy to the terraform-user.

## Generate Access Keys for terraform-user:

    Go to terraform-user > Security Credentials, click Create access key, and save the credentials securely.

## Set Up AWS CLI:
    On your local maachine, open your command line terminal and run the below command
        aws configure
    Enter the Access Key ID, Secret Access Key, and default region (ap-southeast-2).

## Verify Configuration:

    aws sts get-caller-identity

3. Create the Terraform Configuration
   ## Set up the Terraform project:
    Create a new folder named infra in your source folder
        mkdir infra
        cd infra

    ## Create main.tf inside infra folder: Add the following terraform configuration:

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

        resource "aws_lambda_function" "healthcheck" {
        function_name = "healthcheck-api"
        runtime       = "nodejs22.x"
        handler       = "lambda.handler"
        filename      = "${path.module}/healthcheck.zip"

        source_code_hash = filebase64sha256("${path.module}/healthcheck.zip")
        role             = aws_iam_role.lambda_exec.arn

        tags = {
            terraform = "true"
            createdBy = "Your_Name"
        }
        }

        resource "aws_api_gateway_rest_api" "healthcheck_api" {
        name = "HealthCheckAPI"

        tags = {
            terraform = "true"
            createdBy = "Your_Name"
        }
        }

        resource "aws_api_gateway_resource" "healthcheck_resource" {
        rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
        parent_id   = aws_api_gateway_rest_api.healthcheck_api.root_resource_id
        path_part   = "healthcheck"
        }

        resource "aws_api_gateway_method" "healthcheck_method" {
        rest_api_id   = aws_api_gateway_rest_api.healthcheck_api.id
        resource_id   = aws_api_gateway_resource.healthcheck_resource.id
        http_method   = "POST"
        authorization = "NONE"
        }

        resource "aws_api_gateway_integration" "healthcheck_integration" {
        rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
        resource_id = aws_api_gateway_resource.healthcheck_resource.id
        http_method = aws_api_gateway_method.healthcheck_method.http_method

        integration_http_method = "POST"
        type                    = "AWS_PROXY"
        uri                     = aws_lambda_function.healthcheck.invoke_arn
        }

        resource "aws_lambda_permission" "api_gateway" {
        statement_id  = "AllowAPIGatewayInvoke"
        action        = "lambda:InvokeFunction"
        function_name = aws_lambda_function.healthcheck.arn
        principal     = "apigateway.amazonaws.com"
        source_arn    = "${aws_api_gateway_rest_api.healthcheck_api.execution_arn}/*"
        }

        resource "aws_api_gateway_deployment" "healthcheck_deployment" {
        depends_on  = [aws_api_gateway_integration.healthcheck_integration]
        rest_api_id = aws_api_gateway_rest_api.healthcheck_api.id
        }

        resource "aws_api_gateway_stage" "healthcheck_stage" {
        deployment_id = aws_api_gateway_deployment.healthcheck_deployment.id
        rest_api_id   = aws_api_gateway_rest_api.healthcheck_api.id
        stage_name    = "dev"

        tags = {
            terraform = "true"
            createdBy = "Your_Name"
        }
        }

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
            createdBy = "Your_Name"
        }
        }

        resource "aws_iam_policy_attachment" "lambda_policy_attach" {
        name       = "lambda_policy_attach"
        roles      = [aws_iam_role.lambda_exec.name]
        policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        }

    ## Prepare Deployment Files: Package the Lambda function: (create a zip file of your api code)

        zip -r healthcheck.zip index.js lambda.js node_modules

4. Deploy Using Terraform
    # Initialize Terraform:

        terraform init
    # Plan the Deployment:

        terraform plan
    # Apply the Configuration:

        terraform apply
5. Test the API
    # Test the deployed API Gateway endpoint:
    obtain the api invoke url or api gateway url in teh api gateway console, stages section

    curl -X POST https://<api-gateway-url>/dev/healthcheck

6. Clean Up Resources
To destroy all resources created by Terraform, run:

    terraform destroy