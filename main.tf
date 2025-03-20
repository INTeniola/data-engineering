provider "aws" {
  region = var.aws_region
}

# Get current account ID
data "aws_caller_identity" "current" {}

# IoT Core setup
resource "aws_iot_thing" "test_device" {
  name = "apt123"
}

resource "aws_iot_policy" "device_policy" {
  name = "energy-monitoring-device-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["iot:Connect"]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action   = ["iot:Publish"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/energy-monitoring/energy/data"]
      }
    ]
  })
}

# IoT Rule for processing incoming data
resource "aws_iot_topic_rule" "energy_data_rule" {
  name        = "energy_data_processing"
  description = "Process incoming energy data"
  enabled     = true
  sql         = "SELECT * FROM 'energy-monitoring/energy/data'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.process_energy_data.arn
  }
}

# DynamoDB setup
resource "aws_dynamodb_table" "energy_data" {
  name           = "energy-consumption-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "device_id"
  range_key      = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }
}

# S3 setup
resource "aws_s3_bucket" "data_storage" {
  bucket = "energy-monitoring-data-${data.aws_caller_identity.current.account_id}"
}

# Lambda function for processing energy data
resource "aws_lambda_function" "process_energy_data" {
  function_name = "process-energy-data"
  filename      = "process_energy_data.zip"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.energy_data.name
      S3_BUCKET      = aws_s3_bucket.data_storage.bucket
    }
  }
}

# Lambda function for batch processing
resource "aws_lambda_function" "batch_energy_data" {
  function_name = "batch-energy-data"
  filename      = "batch_energy_data.zip"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.energy_data.name
      S3_BUCKET      = aws_s3_bucket.data_storage.bucket
    }
  }
}

# EventBridge rule for scheduled batch processing
resource "aws_cloudwatch_event_rule" "hourly_batch" {
  name                = "hourly-energy-data-batch"
  description         = "Trigger batch processing hourly"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "batch_lambda_target" {
  rule      = aws_cloudwatch_event_rule.hourly_batch.name
  target_id = "BatchEnergyData"
  arn       = aws_lambda_function.batch_energy_data.arn
}

# API Gateway
resource "aws_api_gateway_rest_api" "energy_api" {
  name        = "energy-monitoring-api"
  description = "API for energy consumption data"
}

resource "aws_api_gateway_resource" "energy" {
  rest_api_id = aws_api_gateway_rest_api.energy_api.id
  parent_id   = aws_api_gateway_rest_api.energy_api.root_resource_id
  path_part   = "energy"
}

resource "aws_api_gateway_resource" "device" {
  rest_api_id = aws_api_gateway_rest_api.energy_api.id
  parent_id   = aws_api_gateway_resource.energy.id
  path_part   = "device"
}

resource "aws_api_gateway_resource" "device_id" {
  rest_api_id = aws_api_gateway_rest_api.energy_api.id
  parent_id   = aws_api_gateway_resource.device.id
  path_part   = "{device_id}"
}

resource "aws_api_gateway_method" "get_device_data" {
  rest_api_id   = aws_api_gateway_rest_api.energy_api.id
  resource_id   = aws_api_gateway_resource.device_id.id
  http_method   = "GET"
  authorization_type = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.energy_api.id
  resource_id = aws_api_gateway_resource.device_id.id
  http_method = aws_api_gateway_method.get_device_data.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_device_data.invoke_arn
}

# Lambda function for API requests
resource "aws_lambda_function" "get_device_data" {
  function_name = "get-device-data"
  filename      = "get_device_data.zip"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.energy_data.name
    }
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_exec_role" {
  name = "energy-monitoring-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policies for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "energy-monitoring-lambda-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.energy_data.arn
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.data_storage.arn}",
          "${aws_s3_bucket.data_storage.arn}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Permissions for IoT to invoke Lambda
resource "aws_lambda_permission" "iot_to_lambda" {
  statement_id  = "AllowInvokeFromIoT"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_energy_data.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.energy_data_rule.arn
}

# Permissions for API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_device_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.energy_api.execution_arn}/*/*"
}

# Permissions for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_energy_data.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_batch.arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.energy_api.id
  stage_name  = "prod"
}
