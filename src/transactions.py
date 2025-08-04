import json
import boto3
import uuid

dynamo = boto3.client('dynamodb')


def lambda_handler(event, context):
    http_method = event.get("httpMethod", "GET")
    if http_method == "POST":
        # Espera: { cedula, fondo, operacion, monto }
        try:
            request_data = json.loads(event.get("body", "{}"))
            cedula = request_data.get("cedula")
            fondo = request_data.get("fondo")
            operacion = request_data.get("operacion")
            monto = float(request_data.get("monto", 0))
            if not (cedula and fondo and operacion and monto):
                return {"statusCode": 400, "body": json.dumps({"message": "Missing required fields"})}

            # Buscar usuario
            user_resp = dynamo.scan(
                TableName="users",
                FilterExpression="cedula = :cedula",
                ExpressionAttributeValues={":cedula": {"S": cedula}}
            )
            if not user_resp.get("Items"):
                return {"statusCode": 404, "body": json.dumps({"message": "User not found"})}

            # Registrar transacción
            transaction_id = str(uuid.uuid4())
            dynamo.put_item(
                TableName="transactions",
                Item={
                    "id": {"S": transaction_id},
                    "user": {"S": cedula},
                    "fondo": {"S": fondo},
                    "tipo_transaccion": {"S": operacion},
                    "monto": {"N": str(monto)}
                }
            )
            return {"statusCode": 200, "body": json.dumps({"message": "Transaction successful"})}
        except Exception as e:
            return {"statusCode": 500, "body": json.dumps({"message": str(e)})}

    elif http_method == "GET":
        # Espera: queryStringParameters: { user }
        try:
            user = None
            if event.get("queryStringParameters"):
                user = event["queryStringParameters"].get("user")
            if not user:
                return {"statusCode": 400, "body": json.dumps({"message": "Missing user parameter"})}
            # Buscar transacciones del usuario
            resp = dynamo.scan(
                TableName="transactions",
                FilterExpression="#u = :user",
                ExpressionAttributeNames={"#u": "user"},
                ExpressionAttributeValues={":user": {"S": user}}
            )
            items = resp.get("Items", [])
            result = []
            for item in items:
                result.append({
                    "id": item["id"]["S"],
                    "user": item["user"]["S"],
                    "fondo": item["fondo"]["S"],
                    "tipo_transaccion": item["tipo_transaccion"]["S"],
                    "monto": float(item["monto"]["N"])
                })
            return {"statusCode": 200, "body": json.dumps(result)}
        except Exception as e:
            return {"statusCode": 500, "body": json.dumps({"message": str(e)})}
