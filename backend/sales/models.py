from django.db import models
from django.conf import settings

# Create your models here.



class FinalProduct(models.Model):
    codigo_barras = models.CharField(max_length=100, unique=True)
    nombre = models.CharField(max_length=100)
    precio_venta = models.DecimalField(max_digits=10, decimal_places=2)
    stock_actual = models.IntegerField(default=0)

    def __str__(self):
        return self.nombre

class Venta(models.Model):
    TIPO_VENTA = [
        ('LOCAL', 'Venta en Local'),
        ('PEDIDO', 'Pedido a Domicilio/Tienda'),
    ]
    fecha = models.DateTimeField(auto_now_add=True)
    tipo = models.CharField(max_length=10, choices=TIPO_VENTA)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    usuario_vendedor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    
    # Para el cliente (puede ser nulo si es venta rápida en local)
    cliente_nombre = models.CharField(max_length=200, blank=True, null=True)

class DetalleVenta(models.Model):
    venta = models.ForeignKey(Venta, related_name='detalles', on_delete=models.CASCADE)
    producto = models.ForeignKey(FinalProduct, on_delete=models.PROTECT)
    cantidad = models.IntegerField()
    precio_unitario = models.DecimalField(max_digits=10, decimal_places=2) # Se guarda por si el precio cambia a futuro

class CorteCaja(models.Model):
    fecha = models.DateTimeField(auto_now_add=True)
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    monto_apertura = models.DecimalField(max_digits=10, decimal_places=2)
    monto_cierre_real = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    esta_cerrada = models.BooleanField(default=False)