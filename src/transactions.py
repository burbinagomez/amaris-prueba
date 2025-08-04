import json
import boto3
import uuid

dynamo = boto3.client('dynamodb')

def lambda_handler(event, context):
    if event.get("httpMethod") == "POST":
        request_data = json.loads(event.get("body"))
        user = dynamo.get_item(
            TableName="users",
            Key={
                "cedula": {
                    "S": request_data.get("cedula")
                },
                "correo": {
                    "S": request_data.get("correo")
                }
            }
        )
        fondo = dynamo.get_item(
            TableName="fondo",
            Key={
                "nombre": {
                    "S": request_data.get("fondo",{}).get("nombre")
                },
                "categoria": {
                    "S": request_data.get("fondo",{}).get("categoria")
                }
            }
        )

        if request_data.get("operacion"):
            last_transaction = dynamo.get_item(
                TableName="transactions",
                Key={
                    "user": {
                        "S": user.get("Item", user.get("Attributes")).get("cedula")["S"]
                    },
                    "fondo": {
                        "S": fondo.get("Item",{}).get("nombre")["S"]
                    }
                }
            )
            monto = float(last_transaction.get("Item").get("monto")) + float(request_data.get("monto",0))
            transaction = dynamo.put_item(
                TableName="transactions",
                Item={
                    "id": {
                        "S": str(uuid.uuid4())
                    },
                    "user": {
                        "S": user.get("Item", user.get("Attributes")).get("cedula")["S"]
                    },
                    "fondo": {
                        "S": fondo.get("Item",{}).get("nombre")["S"]
                    },
                    "tipo_transaccion": {
                        "S": request_data.get("operacion")
                    },
                    "monto": {
                        "N": monto if request_data.get("operacion") == "deposito" else 0
                    }
                },
                ReturnValues= "ALL_OLD" 
            )

            if request_data.get("operacion") == "cancelar":
                user = dynamo.put_item(
                    TableName="users",
                    Item={
                        "cedula": {
                            "S": request_data.get("cedula")
                        },
                        "correo": {
                            "S": request_data.get("correo")
                        },
                        "saldo": {
                            "N": monto
                        }
                    },
                    ReturnValues= "ALL_OLD" 
                )
