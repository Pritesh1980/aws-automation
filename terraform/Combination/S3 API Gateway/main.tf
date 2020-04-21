provider "aws" {
  profile    = "work-user"
  region = var.region
}

# Create S3 Full Access Policy
resource "aws_iam_policy" "s3_policy" {
  name        = "s3-policy-tf"
  description = "Policy for allowing all S3 Actions"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF
}

# Create API Gateway Role
resource "aws_iam_role" "s3_api_gateway_role" {
  name = "s3-api-gateway-role-tf"

  # Create Trust Policy for API Gateway
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
} 
  EOF
}

# Attach S3 Access Policy to the API Gateway Role
resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  role       = aws_iam_role.s3_api_gateway_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

## API Key and dependant pieces
resource "aws_api_gateway_usage_plan" "myusageplan" {
  name = "tf_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.pm535-tf-api.id
    stage  = aws_api_gateway_deployment.S3APIDeployment.stage_name
  }
}

resource "aws_api_gateway_api_key" "mykey" {
  name = "tf_api_key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.mykey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.myusageplan.id
}
# /API Key section

resource "aws_api_gateway_rest_api" "pm535-tf-api" {
  name        = "pm535-tf-api"
  description = "API for S3 Integration"

    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

resource "aws_api_gateway_resource" "Folder" {
  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  parent_id   = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  path_part   = "{folder}"
}

resource "aws_api_gateway_resource" "Item" {
  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  parent_id   = aws_api_gateway_resource.Folder.id
  path_part   = "{item}"
}

resource "aws_api_gateway_method" "GetBuckets" {
  rest_api_id   = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id   = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "S3Integration" {
  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method

  # Included because of this issue: https://github.com/hashicorp/terraform/issues/10501
  integration_http_method = "GET"

  type = "AWS"

  # See uri description: https://docs.aws.amazon.com/apigateway/api-reference/resource/integration/
  uri         = "arn:aws:apigateway:${var.region}:s3:path//"
  credentials = aws_iam_role.s3_api_gateway_role.arn
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp"      = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type"   = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "response_400" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = "400"
}

resource "aws_api_gateway_method_response" "response_500" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "integration_response_200" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_parameters = {
    "method.response.header.Timestamp"      = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type"   = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_400" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = aws_api_gateway_method_response.response_400.status_code

  selection_pattern = "4\\d{2}"
}

resource "aws_api_gateway_integration_response" "integration_response_500" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  resource_id = aws_api_gateway_rest_api.pm535-tf-api.root_resource_id
  http_method = aws_api_gateway_method.GetBuckets.http_method
  status_code = aws_api_gateway_method_response.response_500.status_code

  selection_pattern = "5\\d{2}"
}

resource "aws_api_gateway_deployment" "S3APIDeployment" {
  depends_on  = [aws_api_gateway_integration.S3Integration]
  rest_api_id = aws_api_gateway_rest_api.pm535-tf-api.id
  stage_name  = "MyS3"
}