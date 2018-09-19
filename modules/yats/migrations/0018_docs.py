# -*- coding: utf-8 -*-
# Generated by Django 1.11.14 on 2018-09-16 16:08
from __future__ import unicode_literals

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone
import markdownx.models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('yats', '0017_auto_20180914_1223'),
    ]

    operations = [
        migrations.CreateModel(
            name='docs',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('active_record', models.BooleanField(default=True)),
                ('c_date', models.DateTimeField(default=django.utils.timezone.now, verbose_name='creation time')),
                ('u_date', models.DateTimeField(default=django.utils.timezone.now)),
                ('d_date', models.DateTimeField(null=True)),
                ('caption', models.CharField(max_length=255)),
                ('text', markdownx.models.MarkdownxField()),
                ('c_user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='+', to=settings.AUTH_USER_MODEL, verbose_name='creator')),
                ('d_user', models.ForeignKey(null=True, on_delete=django.db.models.deletion.CASCADE, related_name='+', to=settings.AUTH_USER_MODEL)),
                ('u_user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='+', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'abstract': False,
            },
        ),
    ]