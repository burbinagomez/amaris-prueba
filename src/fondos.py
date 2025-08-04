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
        if len(items) > 0:
            new_items = []
            for item in items:
                new_item = {}
                for key,value in item.items():
                    new_item[key] = value.get("S",value.get("N"))
                new_items.append(new_item)
            items = new_items

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