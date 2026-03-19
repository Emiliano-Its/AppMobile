from rest_framework import serializers
from .models import Venta, DetalleVenta, FinalProduct

class FinalProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = FinalProduct
        fields = '__all__'

class SaleDetailSerializer(serializers.ModelSerializer):
    # Usamos producto_nombre para que coincida con lo que Flutter espera
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre')

    class Meta:
        model = DetalleVenta
        # 'producto' es el ID para el POST, 'producto_nombre' es para el GET en Flutter
        fields = ['id', 'producto', 'producto_nombre', 'cantidad', 'precio_unitario']

class SaleSerializer(serializers.ModelSerializer):
    # 'details' mapea a 'detalles' en el modelo por el related_name
    details = SaleDetailSerializer(many=True, source='detalles', required=False)
    seller_name = serializers.ReadOnlyField(source='usuario_vendedor.username', default="Cliente App")
    
    class Meta:
        model = Venta
        fields = [
            'id', 
            'fecha', 
            'tipo', 
            'total', 
            'usuario_vendedor', 
            'seller_name', 
            'cliente_nombre', 
            'direccion_envio',           # <--- AGREGADO
            'fecha_entrega_estimada',     # <--- AGREGADO
            'estado', 
            'details'
        ]
        # Hacemos el vendedor opcional en la validación del Serializer
        extra_kwargs = {
            'usuario_vendedor': {'required': False, 'allow_null': True}
        }

    def create(self, validated_data):
        # 1. Extraer los detalles (usamos 'detalles' porque es el source)
        details_data = validated_data.pop('detalles', [])
        
        # 2. Crear la venta (direccion_envio y fecha_entrega_estimada ya vienen en validated_data)
        sale = Venta.objects.create(**validated_data)
        
        # 3. Crear detalles
        for detail in details_data:
            product = detail.get('producto')
            qty = detail.get('cantidad')
            price = detail.get('precio_unitario')

            DetalleVenta.objects.create(
                venta=sale,
                producto=product,
                cantidad=qty,
                precio_unitario=price
            )
            
            # Descontar del inventario solo si es venta LOCAL o si decides 
            # descontarlo al aceptar el pedido después.
            if sale.tipo == 'LOCAL':
                product.stock_actual -= int(qty)
                product.save()
            
        return sale