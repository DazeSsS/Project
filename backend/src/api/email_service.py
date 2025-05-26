import json
import boto3
from django.conf import settings


def add_email_task(subject, message, html_message, recipient_list):
    session = boto3.session.Session(
        aws_access_key_id=settings.YMQ_ACCESS_KEY,
        aws_secret_access_key=settings.YMQ_SECRET_KEY,
        region_name='ru-central1'
    )
    
    sqs = session.resource(
        service_name='sqs',
        endpoint_url='https://message-queue.api.cloud.yandex.net'
    )
    
    queue = sqs.Queue(settings.YMQ_QUEUE_URL)
    
    email_data = {
        'subject': subject,
        'text_body': message,
        'html_body': html_message,
        'recipients': recipient_list,
    }
    
    response = queue.send_message(
        MessageBody=json.dumps(email_data, ensure_ascii=False)
    )
