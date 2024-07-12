from django.http import HttpResponse
from django.shortcuts import render


def analyze_files(request, file):
    print(request)
    return HttpResponse(f'Archivo {file} Analizado')


def analyze_bucket(bucket):
    print(f'Scanning Bucket = {bucket}')
    return HttpResponse(f'Bucket {bucket} Analizado')


def reports(request):
    print(f'Reportes Generados')
    return HttpResponse('Reportes Generados')


def login(request, token):
    if token == 1234:
        print(f'Access to Login Endpoint with Token: {token}\n')
        return HttpResponse(f'Access to Login Endpoint {token}\n')
    else:
        print('Access Denied\n')
        return HttpResponse(f'Access Denied\n')


def index(request):
    emails = ['johanluna777@gmail.com', 'josemanuel2010@gmail.com',
              'johanluna_1994@hotmail.com', 'linaluna410@gmail.com']
    context = {'emails': emails}
    return render(request, 'index.html', context)
