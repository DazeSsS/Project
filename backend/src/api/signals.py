import requests
import json
from datetime import datetime, timedelta

from django.conf import settings
from django.dispatch import receiver
from django.db.models.signals import m2m_changed, post_save, pre_delete

from api.models import User, Check, Practice, PracticeGroup, PaymentAccount


@receiver(post_save, sender=User)
def create_account(sender, instance, created, **kwargs):
    if created:
        PaymentAccount.objects.create(user=instance)


@receiver(m2m_changed, sender=Practice.attended.through)
def calculate_students_balance(sender, instance, action, pk_set, **kwargs):
    if action == 'pre_add':
        for student_id in pk_set:
            student = User.objects.get(pk=student_id)
            student.account.increase_debt(instance.price)

    if action == 'pre_remove':
        for student_id in pk_set:
            student = User.objects.get(pk=student_id)
            student.account.reduce_debt(instance.price)
