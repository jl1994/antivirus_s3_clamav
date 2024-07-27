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
    path("record-scan/", views.record_scan, name="record-scan"),
    path("get-scan-statistics/", views.get_scan_statistics, name="get-scan-statistics"),
     path('download-file/', views.download_file_view, name='download_file'),
]



