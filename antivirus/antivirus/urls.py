from django.contrib import admin
from django.urls import path
from . import views

urlpatterns = [
    path("",  views.index,    name="index"),
    path("admin/", admin.site.urls),
    path("login/<str:user_id>", views.login, name="login"),
    path("scan-messages/", views.scan_messages, name="scan-messages"),
    path("scan-sqs-messages/", views.scan_sqs_messages, name="scan-sqs-messages"),
    path("contact/", views.contact, name="contact"),
]
