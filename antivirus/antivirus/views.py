from django.http import HttpResponse
from django.shortcuts import render


def index(request):
    return render(request, "index.html", {})


def login(request, user_id):
    roles = ["admin", "user", "guest"]
    context = {"user_id": user_id, "roles": roles}
    return render(request, "login.html", context)


def scan_messages(request):
    return render(request, "scan_messages.html", {})


def scan_sqs_messages(request):
    return HttpResponse("Endpoint Scan Messages")


def contact(request):
    return render(request, "contact.html", {})
