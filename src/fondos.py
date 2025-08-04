import boto3
import json

def lambda_handler(event, context):
    # Inicializa el cliente de DynamoDB
    dynamodb = boto3.client('dynamodb')


    try:
        # Escanea toda la tabla. Nota: Para tablas grandes, considera paginación.
        response = dynamodb.scan(TableName="fondos")

        # Extrae los elementos de la respuesta
        items = response.get('Items', [])

        # Devuelve los datos en formato JSON
        return {
            'statusCode': 200,
            'body': json.dumps(items)
        }

    except Exception as e:
        # En caso de error, devuelve un mensaje de error
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error al obtener los datos de DynamoDB: {str(e)}')
        }