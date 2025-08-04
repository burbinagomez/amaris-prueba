# Define el backend remoto de Terraform para almacenar el estado
terraform {
  backend "s3" {
    bucket         = "terraform-amaris"
    key            = "infra/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-state-locking"
  }
}

# Define el proveedor de AWS y la región
provider "aws" {
  region = "us-east-2"
}

# --- DynamoDB Tables ---

resource "aws_dynamodb_table" "users" {
  name             = "users"
  billing_mode     = "PROVISIONED"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "cedula"
  range_key        = "correo"

  attribute {
    name = "cedula"
    type = "S"
  }

  attribute {
    name = "correo"
    type = "S"
  }
}

resource "aws_dynamodb_table" "fondos" {
  name             = "fondos"
  billing_mode     = "PROVISIONED"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "nombre"
  range_key        = "categoria"

  attribute {
    name = "nombre"
    type = "S"
  }

  attribute {
    name = "categoria"
    type = "S"
  }
}

resource "aws_dynamodb_table" "transactions" {
  name             = "transactions"
  billing_mode     = "PROVISIONED"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "id"
  range_key        = "user"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "user"
    type = "S"
  }
}

# --- IAM Roles for Lambdas ---

resource "aws_iam_role" "lambda_amaris_iam_role" {
  name = "lambda-amaris-execution-role"
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
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_amaris_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_amaris_iam_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.fondos.arn,
          aws_dynamodb_table.transactions.arn
        ]
      }
    ]
  })
}

# --- Lambda Functions ---

resource "aws_lambda_function" "fondos" {
  function_name    = "fondos"
  handler          = "fondos.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_amaris_iam_role.arn
  filename         = "fondos.zip"
  source_code_hash = filebase64sha256("fondos.zip")
}

resource "aws_lambda_function" "subscribe" {
  function_name    = "subscribe"
  handler          = "subscribe.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_amaris_iam_role.arn
  filename         = "subscribe.zip"
  source_code_hash = filebase64sha256("subscribe.zip")
}

resource "aws_lambda_function" "transactions" {
  function_name    = "transactions"
  handler          = "transactions.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_amaris_iam_role.arn
  filename         = "transactions.zip"
  source_code_hash = filebase64sha256("transactions.zip")
}

# --- API Gateway v2 (HTTP API) ---

# Define la API Gateway HTTP
resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "amaris-http-api"
  protocol_type = "HTTP"

  # CORRECCIÓN: Habilitar la política CORS
  cors_configuration {
    allow_origins = ["http://${aws_s3_bucket_website_configuration.static_website_configuration.website_endpoint}"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_credentials = true
  }
}

# Integración para la Lambda 'fondos'
resource "aws_apigatewayv2_integration" "fondos_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.fondos.invoke_arn
  integration_method = "POST"
}

# Integración para la Lambda 'subscribe'
resource "aws_apigatewayv2_integration" "subscribe_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.subscribe.invoke_arn
  integration_method = "POST"
}

# Integración para la Lambda 'transactions'
resource "aws_apigatewayv2_integration" "transactions_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.transactions.invoke_arn
  integration_method = "POST"
}

# Rutas para los endpoints
resource "aws_apigatewayv2_route" "fondos_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /fondos"
  target    = "integrations/${aws_apigatewayv2_integration.fondos_integration.id}"
}

resource "aws_apigatewayv2_route" "subscribe_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "POST /subscribe"
  target    = "integrations/${aws_apigatewayv2_integration.subscribe_integration.id}"
}

resource "aws_apigatewayv2_route" "transactions_get_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /transactions"
  target    = "integrations/${aws_apigatewayv2_integration.transactions_integration.id}"
}

resource "aws_apigatewayv2_route" "transactions_post_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "POST /transactions"
  target    = "integrations/${aws_apigatewayv2_integration.transactions_integration.id}"
}

# Despliegue de la API
resource "aws_apigatewayv2_deployment" "api_deployment" {
  api_id      = aws_apigatewayv2_api.api_gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_apigatewayv2_route.fondos_route.id,
      aws_apigatewayv2_route.subscribe_route.id,
      aws_apigatewayv2_route.transactions_get_route.id,
      aws_apigatewayv2_route.transactions_post_route.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Definición explícita del stage para la API
resource "aws_apigatewayv2_stage" "dev" {
  api_id        = aws_apigatewayv2_api.api_gateway.id
  name          = "dev"
  auto_deploy   = true 
}

# --- Permisos para que API Gateway invoque a las Lambdas (CORREGIDO) ---
resource "aws_lambda_permission" "fondos_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayV2-fondos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fondos.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*"
}

resource "aws_lambda_permission" "subscribe_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayV2-subscribe"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*"
}

resource "aws_lambda_permission" "transactions_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayV2-transactions"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transactions.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*"
}


# --- S3 Static Website ---

resource "aws_s3_bucket" "static_website" {
  bucket = "amaris-static-website-12345"
}

resource "aws_s3_bucket_public_access_block" "static_website_public_access_block" {
  bucket = aws_s3_bucket.static_website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "static_website_policy" {
  bucket = aws_s3_bucket.static_website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "static_website_configuration" {
  bucket = aws_s3_bucket.static_website.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_website.id
  key          = "index.html"
  source       = "index.html"
  acl          = "public-read"
  content_type = "text/html"
}

# --- Outputs ---

output "api_gateway_url" {
  description = "El URL del endpoint de la API Gateway."
  value       = aws_apigatewayv2_stage.dev.invoke_url
}

output "static_website_url" {
  description = "El URL del endpoint del sitio web estático en S3."
  value       = aws_s3_bucket_website_configuration.static_website_configuration.website_endpoint
}