from django.http import HttpResponse


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
