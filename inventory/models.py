from django.db import models

# Create your models here.

from django.contrib.auth.models import User

class MateriaPrima(models.Model):
    # Usamos CharField para el código de barras porque puede contener letras o ceros a la izquierda
    codigo_barras = models.CharField(max_length=100, unique=True, verbose_name="Código de Barras")
    nombre = models.CharField(max_length=100)
    unidad_medida = models.CharField(max_length=20, help_text="Ej: Bulto 50kg, Litro, Caja")
    stock_actual = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    precio_ultimo_ingreso = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nombre} - {self.stock_actual} {self.unidad_medida}"

class MovimientoInventario(models.Model):
    TIPO_CHOICES = [
        ('ENTRADA', 'Entrada (Recepción)'),
        ('SALIDA', 'Salida (Retiro de producción)'),
    ]
    
    materia_prima = models.ForeignKey(MateriaPrima, on_delete=models.CASCADE)
    tipo = models.CharField(max_length=10, choices=TIPO_CHOICES)
    cantidad = models.DecimalField(max_digits=10, decimal_places=2)
    usuario = models.ForeignKey(User, on_delete=models.PROTECT) # Protege para no borrar historial si se borra el user
    fecha = models.DateTimeField(auto_now_add=True)
    comentario = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.tipo} de {self.cantidad} {self.materia_prima.nombre}"