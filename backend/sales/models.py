from django.db import models
from django.conf import settings
from django.db.models import Sum

class FinalProduct(models.Model):
    codigo_barras = models.CharField(max_length=100, unique=True, null=True, blank=True)       
    nombre = models.CharField(max_length=100)
    precio_venta = models.DecimalField(max_digits=10, decimal_places=2)
    stock_actual = models.IntegerField(default=0)
    activo = models.BooleanField(default=True)
    imagen = models.ImageField(upload_to='productos/', null=True, blank=True)

    def __str__(self):
        return self.nombre

class RegistroProduccion(models.Model):
    """
    PUENTE DE ESTADÍSTICAS: Une el maíz (inventory) con las tostadas (sales).
    """
    fecha = models.DateTimeField(auto_now_add=True)
    # Referencia a la app inventory usando string para evitar errores
    materia_prima = models.ForeignKey('inventory.RawMaterial', on_delete=models.CASCADE)
    cantidad_insumo_usada = models.DecimalField(max_digits=10, decimal_places=2)
    
    # Producto obtenido
    producto_final = models.ForeignKey(FinalProduct, on_delete=models.CASCADE)
    cantidad_paquetes_producidos = models.PositiveIntegerField()
    
    # Campos para optimización calculados automáticamente
    costo_insumo_momento = models.DecimalField(max_digits=10, decimal_places=2, editable=False)
    rendimiento_calculado = models.DecimalField(max_digits=10, decimal_places=2, editable=False)

    def save(self, *args, **kwargs):
        # Calcula cuánto costó el maíz usado basado en el precio de compra
        self.costo_insumo_momento = self.cantidad_insumo_usada * self.materia_prima.precio_ultimo_ingreso
        # Calcula rendimiento (Paquetes por cada unidad de insumo)
        if self.cantidad_insumo_usada > 0:
            self.rendimiento_calculado = self.cantidad_paquetes_producidos / self.cantidad_insumo_usada
        else:
            self.rendimiento_calculado = 0
        super().save(*args, **kwargs)

class Venta(models.Model):
    TIPO_VENTA = [('LOCAL', 'Venta en Local'), ('PEDIDO', 'Pedido a Domicilio/Tienda')]
    ESTADO_PEDIDO = [
        ('PENDIENTE', 'Pendiente'), ('ACEPTADO', 'Aceptado'),
        ('EN_CAMINO', 'En Camino'), ('ENTREGADO', 'Entregado'), ('RECHAZADO', 'Rechazado'),
    ]
    fecha = models.DateTimeField(auto_now_add=True)
    fecha_cobro = models.DateTimeField(null=True, blank=True)  # Se llena al cobrar
    tipo = models.CharField(max_length=10, choices=TIPO_VENTA)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    usuario_vendedor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, null=True, blank=True)
    cliente_nombre = models.CharField(max_length=200, blank=True, null=True)
    direccion_envio = models.TextField(blank=True, null=True)
    fecha_entrega_estimada = models.TextField(blank=True, null=True) 
    estado = models.CharField(max_length=20, choices=ESTADO_PEDIDO, default='PENDIENTE')

    def __str__(self):
        return f"Venta {self.id} - {self.tipo}"

class DetalleVenta(models.Model):
    venta = models.ForeignKey(Venta, related_name='detalles', on_delete=models.CASCADE)
    producto = models.ForeignKey(FinalProduct, on_delete=models.PROTECT)
    cantidad = models.IntegerField()
    precio_unitario = models.DecimalField(max_digits=10, decimal_places=2)

    @property
    def producto_nombre(self):
        return self.producto.nombre

class CorteCaja(models.Model):
    fecha = models.DateTimeField(auto_now_add=True)
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    monto_apertura = models.DecimalField(max_digits=10, decimal_places=2)
    monto_cierre_real = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    esta_cerrada = models.BooleanField(default=False)

    def calcular_ventas_del_periodo(self):
        total = Venta.objects.filter(
            usuario_vendedor=self.usuario,
            fecha__gte=self.fecha,
            estado='ENTREGADO'
        ).aggregate(total_ventas=Sum('total'))['total_ventas']
        return total or 0

    def __str__(self):
        estado = "Cerrada" if self.esta_cerrada else "Abierta"
        return f"Corte {self.fecha.strftime('%d/%m/%Y')} - {estado}"