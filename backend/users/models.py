from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    # Django already has username, password, email. 
    # We just add your custom fields:
    telefono = models.CharField(max_length=15, blank=True, null=True)
    direccion = models.TextField(blank=True, null=True)
    rol = models.CharField(
        max_length=20, 
        choices=[('ADMIN', 'Administrador'), ('STAFF', 'Personal')],
        default='STAFF'
    )
    
    # We change how it displays in the admin panel
    def __str__(self):
        return self.username