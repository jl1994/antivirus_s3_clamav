from django.db import models

# Create your models here.
    
from django.db import models

class ScanRecord(models.Model):
    scan_id = models.AutoField(primary_key=True)
    filename = models.CharField(max_length=255)
    bucket_name = models.CharField(max_length=255)
    request_date = models.DateTimeField(auto_now_add=True)
    request_by = models.CharField(max_length=100)
    file_size = models.PositiveIntegerField()  # Tamaño del archivo en bytes
    file_type = models.CharField(max_length=50)  # Tipo de archivo (e.g., pdf, jpg, etc.)
    is_infected = models.BooleanField(default=False)  # Si está infectado o no
    scan_result = models.TextField(blank=True)  # Resultados adicionales del escaneo

    def __str__(self):
        return f'{self.filename} - {self.bucket_name}'
