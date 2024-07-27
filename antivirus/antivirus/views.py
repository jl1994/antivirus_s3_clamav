from django.http import HttpResponse
from django.shortcuts import render
from .models import ScanRecord
from django.http import JsonResponse  # Asegúrate de importar JsonResponse
import datetime
import boto3



def index(request):
    return render(request, "index.html", {})

def record_scan(request):
    # Este es un ejemplo de cómo podrías recibir los datos del escaneo
    filename = request.GET.get('filename', 'example.txt')
    bucket_name = request.GET.get('bucket_name', 'example-bucket')
    is_infected = request.GET.get('is_infected', 'false') == 'true'
    file_size = int(request.GET.get('file_size', 0))
    file_type = request.GET.get('file_type', 'txt')
    scan_result = request.GET.get('scan_result', '')


    scan_record = ScanRecord(
        filename=filename,
        bucket_name=bucket_name,
        is_infected=is_infected,
        file_size=file_size,
        file_type=file_type,
        scan_result=scan_result,
    )
    scan_record.save()

    return HttpResponse(f"Scan record saved for {filename}")



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

def get_scan_statistics(request):
    total_files = ScanRecord.objects.count()
    total_infected = ScanRecord.objects.filter(is_infected=True).count()
    total_clean = total_files - total_infected

    data = {
        'total_files': total_files,
        'total_infected': total_infected,
        'total_clean': total_clean
    }
    return JsonResponse(data)


# Funcionalidad para la descarga del archivo


def download_file_view(request):
    bucket_name = request.GET.get('bucket_name')
    object_key = request.GET.get('object_key')
    download_path = f"/tmp/{os.path.basename(object_key)}"

    success = download_file_from_s3(bucket_name, object_key, download_path)
    if success:
        return JsonResponse({"status": "File downloaded successfully"})
    else:
        return JsonResponse({"status": "Failed to download file"})
    

def download_file_from_s3(bucket_name, object_key, download_path):
    s3_client = boto3.client(
        's3',
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION
    )
    try:
        decoded_object_key = unquote(object_key)
        s3_client.head_object(Bucket=bucket_name, Key=decoded_object_key)
        s3_client.download_file(bucket_name, decoded_object_key, download_path)
        return True
    except (NoCredentialsError, PartialCredentialsError) as e:
        print(f"Credentials error: {e}")
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            print(f"Error: El objeto {object_key} no fue encontrado en el bucket {bucket_name}.")
        else:
            print(f"ClientError: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    return False


