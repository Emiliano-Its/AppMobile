from rest_framework import serializers
from .models import Venta, DetalleVenta, FinalProduct

class FinalProductSerializer(serializers.ModelSerializer):
    # Agregamos el campo de imagen para que Django maneje la URL de los archivos media
    imagen = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = FinalProduct
        # Aseguramos que incluya codigo_barras para que el scanner de Flutter lo encuentre
        # Agregamos 'imagen' al final de la lista de campos
        fields = ['id', 'codigo_barras', 'nombre', 'precio_venta', 'stock_actual', 'activo', 'imagen']

class SaleDetailSerializer(serializers.ModelSerializer):
    # Campo de solo lectura para mostrar el nombre en la lista de pedidos de Flutter
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre')

    class Meta:
        model = DetalleVenta
        # 'producto' es el ID (necesario para el POST)
        fields = ['id', 'producto', 'producto_nombre', 'cantidad', 'precio_unitario']

class SaleSerializer(serializers.ModelSerializer):
    # 'details' mapea al related_name='detalles' del modelo DetalleVenta
    details = SaleDetailSerializer(many=True, source='detalles', required=False)
    seller_name = serializers.ReadOnlyField(source='usuario_vendedor.username', default="Cliente App")
    
    class Meta:
        model = Venta
        fields = [
            'id', 
            'fecha',
            'fecha_cobro',
            'tipo', 
            'total', 
            'usuario_vendedor', 
            'seller_name', 
            'cliente_nombre', 
            'direccion_envio',           
            'fecha_entrega_estimada',     
            'estado', 
            'details'
        ]
        extra_kwargs = {
            'usuario_vendedor': {'required': False, 'allow_null': True}
        }

    def create(self, validated_data):
        # 1. Extraer los detalles
        details_data = validated_data.pop('detalles', [])
        
        # 2. Crear la venta principal
        sale = Venta.objects.create(**validated_data)
        
        # 3. Procesar cada producto del carrito
        for detail in details_data:
            product = detail.get('producto')
            qty = detail.get('cantidad')
            price = detail.get('precio_unitario')

            # Crear el registro del detalle de venta
            DetalleVenta.objects.create(
                venta=sale,
                producto=product,
                cantidad=qty,
                precio_unitario=price
            )
            
            # --- LÓGICA DE INVENTARIO PARA POS (VENTA LOCAL) ---
            if sale.tipo == 'LOCAL':
                # Validamos que no vendamos más de lo que hay (opcional pero recomendado)
                if product.stock_actual >= int(qty):
                    product.stock_actual -= int(qty)
                    product.save()
                else:
                    # Si no hay stock, podrías lanzar una excepción o dejar que baje a negativo
                    # según cómo prefieran manejarlo tus abuelos.
                    product.stock_actual -= int(qty)
                    product.save()
            
        return sale