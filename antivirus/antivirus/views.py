from django.http import HttpResponse
from django.shortcuts import render

# Logica de Autenticacion

VALID_USERS = {
    "johanluna777@gmail.com": "1143966442",
    "josemanuelluna2018@gmail.com": "1104806077"
}


def index(request):
    return render(request, "index.html", {})


def login(request, user_id):
    print(f"User ID: {user_id}")
    username = request.GET.get("username")
    password = request.GET.get("password")
    print(f"User: {username} Password: {password}")
    return HttpResponse("Endpoint Login UserID: " + user_id)


def scan_messages(request):
    return render(request, "scan_messages.html", {})


def scan_sqs_messages(request):
    return HttpResponse("Endpoint Scan Messages")


def contact(request):
    return render(request, "contact.html", {})
