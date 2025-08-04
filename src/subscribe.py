import boto3
import json
import uuid
import os

dynamo = boto3.client('dynamodb')
sns = boto3.client('sns')
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")
required_fields = {"cedula", "correo"}

def lambda_handler(event, context):
    request_data = event.get("body")
    if request_data:
        request_data = json.loads(request_data)
        request_data_keys = set(request_data.keys())
        if required_fields.intersection(request_data_keys) != required_fields:
            return {"statusCode": 400, "message" : f"Faltan los siguientes atributos {required_fields.intersection(request_data_keys)}" }
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
        print(user)
        if not user.get("Item"):
            user = dynamo.put_item(
                TableName="users",
                Item={
                    "cedula": {
                        "S": request_data.get("cedula")
                    },
                    "correo": {
                        "S": request_data.get("correo")
                    },
                    "telefono": {
                        "S": request_data.get("telefono")
                    },
                    "saldo": {
                        "N": str(request_data.get("saldo"))
                    }
                },
                ReturnValues= "ALL_OLD" 
            )
        fondo = dynamo.get_item(
            TableName="fondos",
            Key={
                "nombre": {
                    "S": request_data.get("fondo",{}).get("nombre")
                },
                "categoria": {
                    "S": request_data.get("fondo",{}).get("categoria")
                }
            }
        )

        if user.get("Item", user.get("Attributes")).get("saldo")["N"] >= fondo.get("Item",{}).get("monto_minimo")["N"]:
            transaction_id = str(uuid.uuid4())
            transaction = dynamo.put_item(
                TableName="transactions",
                Item={
                    "id": {
                        "S": transaction_id
                    },
                    "user": {
                        "S": user.get("Item", user.get("Attributes")).get("cedula")["S"]
                    },
                    "fondo": {
                        "S": fondo.get("Item",{}).get("nombre")["S"]
                    },
                    "tipo_transaccion": {
                        "S": "APERTURA"
                    },
                    "monto": {
                        "N": str(request_data.get("saldo"))
                    }
                },
                ReturnValues= "ALL_OLD" 
            )

            message = {
                "transaction_id": transaction_id,
                "user_cedula": user.get("Item", user.get("Attributes")).get("cedula")["S"],
                "fondo_nombre": fondo.get("Item",{}).get("nombre")["S"]
            }
            
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps({'default': json.dumps(message)}),
                MessageStructure='json'
            )

            return {
                'statusCode': 200,
                'body': "Apertura creada correctamente, mas informacion sera enviada a su correo"
            }
        else:
            return {
                'statusCode': 200,
                'body': f"No tiene saldo disponible para vincularse al fondo {fondo.get('Item',{}).get('nombre')['S']}."
            }
        