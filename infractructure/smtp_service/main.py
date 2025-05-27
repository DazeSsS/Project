import os
import json
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def handler(event, context):
    try:
        new_message = json.loads(event['messages'][0]['details']['message']['body'])

        smtp_host = os.environ['EMAIL_HOST']
        smtp_port = int(os.environ['EMAIL_PORT'])
        smtp_user = os.environ['EMAIL_USER']
        smtp_pass = os.environ['EMAIL_PASSWORD']

        msg = MIMEMultipart('alternative')
        msg['Subject'] = new_message['subject']
        msg['From'] = smtp_user
        msg['To'] = ', '.join(new_message['recipients'])

        part1 = MIMEText(new_message['text_body'], 'plain')
        part2 = MIMEText(new_message['html_body'], 'html')

        msg.attach(part1)
        msg.attach(part2)

        with smtplib.SMTP_SSL(smtp_host, smtp_port) as server:
            server.login(smtp_user, smtp_pass)
            server.sendmail(
                msg['From'],
                new_message['recipients'],
                msg.as_string()
            )

        return {'status': 'success'}

    except Exception as e:
        return {
            'status': 'error',
            'error': str(e)
        }