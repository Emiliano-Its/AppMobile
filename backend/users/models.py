from django.contrib.auth.models import AbstractUser
from django.db import models

class CustomUser(AbstractUser):
    # Opciones de Roles
    ROLE_CHOICES = [
        ('ADMIN', 'Administrador'),
        ('STAFF', 'Personal de Ventas'),
        ('CLIENTE', 'Cliente Comprador'), # <--- Nuevo Rol
    ]

    # Campos personalizados
    telefono = models.CharField(
        max_length=15, 
        blank=True, 
        null=True, 
        verbose_name="Teléfono de contacto"
    )
    
    direccion = models.TextField(
        blank=True, 
        null=True, 
        verbose_name="Dirección de entrega"
    )
    
    rol = models.CharField(
        max_length=20, 
        choices=ROLE_CHOICES,
        default='CLIENTE' # Por defecto, los nuevos registros son clientes
    )

    # Campos extra útiles para el futuro (Opcional, por si usas GPS)
    latitud = models.FloatField(blank=True, null=True)
    longitud = models.FloatField(blank=True, null=True)

    class Meta:
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        return f"{self.username} ({self.get_rol_display()})"