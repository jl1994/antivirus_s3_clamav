# Creando nuestra primera vista

from django.http import HttpResponse


def analyze_files(request, file):
    return HttpResponse(f'Archivo {file} Analizado')


def analyze_bucket(bucket):
    print(f'Scanning Bucket = {bucket}')
    return HttpResponse(f'Bucket {bucket} Analizado')


def reports(request):
    print(f'Reportes Generados')
    return HttpResponse('Reportes Generados')
