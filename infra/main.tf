# Define el proveedor de AWS y la región
provider "aws" {
  region = "us-east-1"
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

resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda-execution-role"
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
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_iam_role.id

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

resource "aws_lambda_function" "subscribe" {
  function_name    = "subscribe"
  handler          = "subscribe.handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_iam_role.arn
  filename         = "subscribe.zip"
  source_code_hash = filebase64sha256("subscribe.zip")

  environment {
    variables = {
      DYNAMO_TABLE_USERS = aws_dynamodb_table.users.name
    }
  }
}

resource "aws_lambda_function" "transactions" {
  function_name    = "transactions"
  handler          = "transactions.handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_iam_role.arn
  filename         = "transactions.zip"
  source_code_hash = filebase64sha256("transactions.zip")

  environment {
    variables = {
      DYNAMO_TABLE_TRANSACTIONS = aws_dynamodb_table.transactions.name
    }
  }
}

# --- API Gateway v1 (REST API) ---

resource "aws_api_gateway_rest_api" "api_gateway" {
  name = "amaris-api"
}

# Recurso para el path "/subscribe"
resource "aws_api_gateway_resource" "subscribe_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "subscribe"
}

# Método POST para el path "/subscribe"
resource "aws_api_gateway_method" "subscribe_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.subscribe_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integración del método POST "/subscribe" con la Lambda 'subscribe'
resource "aws_api_gateway_integration" "subscribe_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.subscribe_resource.id
  http_method             = aws_api_gateway_method.subscribe_post_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.subscribe.invoke_arn
}

# Recurso para el path "/transactions"
resource "aws_api_gateway_resource" "transactions_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "transactions"
}

# Método GET para el path "/transactions"
resource "aws_api_gateway_method" "transactions_get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.transactions_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integración del método GET "/transactions" con la Lambda 'transactions'
resource "aws_api_gateway_integration" "transactions_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.transactions_resource.id
  http_method             = aws_api_gateway_method.transactions_get_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.transactions.invoke_arn
}

# Método POST para el path "/transactions"
resource "aws_api_gateway_method" "transactions_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.transactions_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integración del método POST "/transactions" con la Lambda 'transactions'
resource "aws_api_gateway_integration" "transactions_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.transactions_resource.id
  http_method             = aws_api_gateway_method.transactions_post_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.transactions.invoke_arn
}

# Despliegue de la API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id

  # Depende de todas las integraciones para asegurar que el despliegue es completo
  depends_on = [
    aws_api_gateway_integration.subscribe_integration,
    aws_api_gateway_integration.transactions_get_integration,
    aws_api_gateway_integration.transactions_post_integration,
  ]
}

# Permisos para que API Gateway invoque a las Lambdas
resource "aws_lambda_permission" "subscribe_permission" {
  statement_id  = "AllowExecutionFromAPIGateway-subscribe"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "transactions_permission" {
  statement_id  = "AllowExecutionFromAPIGateway-transactions"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transactions.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

# --- Output del endpoint de la API ---
# output "api_gateway_url" {
#   description = "El URL del endpoint de la API Gateway."
#   value       = aws_api_gateway_deployment.api_deployment.triggers
# }