from django.db import models
from django.conf import settings
from django.db.models import Sum

class FinalProduct(models.Model):
    codigo_barras = models.CharField(
        max_length=100, 
        unique=True, 
        null=True,   # Permite que sea nulo en la base de datos
        blank=True   # Permite que el formulario lo acepte vacío
    )       
    nombre = models.CharField(max_length=100)
    precio_venta = models.DecimalField(max_digits=10, decimal_places=2)
    stock_actual = models.IntegerField(default=0)
    activo = models.BooleanField(default=True)
    
    # --- CAMBIO AGREGADO: SOPORTE PARA IMÁGENES ---
    imagen = models.ImageField(upload_to='productos/', null=True, blank=True)

    def __str__(self):
        return self.nombre

class Venta(models.Model):
    TIPO_VENTA = [
        ('LOCAL', 'Venta en Local'),
        ('PEDIDO', 'Pedido a Domicilio/Tienda'),
    ]
    
    ESTADO_PEDIDO = [
        ('PENDIENTE', 'Pendiente de Aceptar'),
        ('ACEPTADO', 'Aceptado / En Preparación'),
        ('EN_CAMINO', 'En Camino'),
        ('ENTREGADO', 'Entregado'),
        ('RECHAZADO', 'Rechazado'),
    ]

    fecha = models.DateTimeField(auto_now_add=True)
    tipo = models.CharField(max_length=10, choices=TIPO_VENTA)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    
    # CORRECCIÓN: null=True permite que los pedidos de la App se creen sin vendedor inicial
    usuario_vendedor = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.PROTECT,
        related_name='ventas_realizadas',
        null=True,
        blank=True
    )
    
    # Datos del Cliente y Envío
    cliente_nombre = models.CharField(max_length=200, blank=True, null=True)
    direccion_envio = models.TextField(blank=True, null=True)
    
    # CORRECCIÓN: TextField para aceptar los rangos de texto que mandas desde Flutter
    fecha_entrega_estimada = models.TextField(blank=True, null=True) 
    
    estado = models.CharField(
        max_length=20, 
        choices=ESTADO_PEDIDO, 
        default='PENDIENTE' # Por defecto PENDIENTE para nuevos pedidos
    )

    def __str__(self):
        return f"Venta {self.id} - {self.tipo} ({self.estado})"

class DetalleVenta(models.Model):
    venta = models.ForeignKey(Venta, related_name='detalles', on_delete=models.CASCADE)
    producto = models.ForeignKey(FinalProduct, on_delete=models.PROTECT)
    cantidad = models.IntegerField()
    precio_unitario = models.DecimalField(max_digits=10, decimal_places=2)

    # Agregamos esto para facilitar la lectura en Flutter
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
        # Filtramos solo ventas LOCALES o pedidos ENTREGADOS para el corte
        total = Venta.objects.filter(
            usuario_vendedor=self.usuario,
            fecha__gte=self.fecha,
            estado='ENTREGADO'
        ).aggregate(total_ventas=Sum('total'))['total_ventas']
        return total or 0

    def __str__(self):
        estado = "Cerrada" if self.esta_cerrada else "Abierta"
        return f"Corte {self.fecha.strftime('%d/%m/%Y')} - {estado}"