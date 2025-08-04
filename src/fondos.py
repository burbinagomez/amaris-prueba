import boto3
import json

def lambda_handler(event, context):
    # Inicializa el cliente de DynamoDB
    dynamodb = boto3.resource('dynamodb')

    # Especifica el nombre de tu tabla
    table = dynamodb.Table('fondos')

    try:
        # Escanea toda la tabla. Nota: Para tablas grandes, considera paginación.
        response = table.scan()

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