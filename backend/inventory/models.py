from django.db import models
from django.conf import settings

class RawMaterial(models.Model):
    codigo_barras = models.CharField(max_length=100, unique=True, verbose_name="Código de Barras")
    nombre = models.CharField(max_length=100)
    unidad_medida = models.CharField(max_length=20, help_text="Ej: kg, Bulto, Litro")
    stock_actual = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    precio_ultimo_ingreso = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nombre} - {self.stock_actual} {self.unidad_medida}"

class MovimientoInventario(models.Model):
    TIPO_CHOICES = [
        ('ENTRADA', 'Entrada (Compra)'),
        ('SALIDA', 'Salida (Merma/Ajuste)'),
        ('PRODUCCION', 'Salida para Producción'), # Necesario para estadísticas
    ]
    
    # Se cambia a minúsculas para coincidir con el __str__
    materia_prima = models.ForeignKey(RawMaterial, on_delete=models.CASCADE, related_name='movimientos')
    tipo = models.CharField(max_length=15, choices=TIPO_CHOICES)
    cantidad = models.DecimalField(max_digits=10, decimal_places=2)
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT) 
    fecha = models.DateTimeField(auto_now_add=True)
    comentario = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.tipo} de {self.cantidad} {self.materia_prima.nombre}"