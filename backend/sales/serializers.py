from rest_framework import serializers
from .models import FinalProduct, Venta, DetalleVenta, CorteCaja

class FinalProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = FinalProduct
        fields = '__all__'

class SaleDetailSerializer(serializers.ModelSerializer):
    product_name = serializers.ReadOnlyField(source='producto.nombre')

    class Meta:
        model = DetalleVenta
        fields = ['id', 'producto', 'product_name', 'cantidad', 'precio_unitario']

class SaleSerializer(serializers.ModelSerializer):
    # Usamos 'detalles' como source porque es el related_name en tu modelo
    details = SaleDetailSerializer(many=True, source='detalles', required=False)
    seller_name = serializers.ReadOnlyField(source='usuario_vendedor.username')

    class Meta:
        model = Venta
        fields = ['id', 'fecha', 'tipo', 'total', 'usuario_vendedor', 'seller_name', 'cliente_nombre', 'details']

    def create(self, validated_data):
        # 1. EXTRAER los detalles de validated_data para que no choquen con el .create()
        # Si no los quitamos, Django intenta asignarlos directamente y lanza el TypeError
        details_data = validated_data.pop('detalles', [])
        
        # 2. Ahora validated_data solo tiene campos directos de la Venta
        sale = Venta.objects.create(**validated_data)
        
        # 3. Iteramos sobre los detalles extraídos
        for detail in details_data:
            product = detail.get('producto')
            qty = detail.get('cantidad')
            price = detail.get('precio_unitario')

            # Creamos el detalle asociado a la venta
            DetalleVenta.objects.create(
                venta=sale,
                producto=product,
                cantidad=qty,
                precio_unitario=price
            )
            
            # Lógica de descuento de stock solo si es venta LOCAL
            if sale.tipo == 'LOCAL':
                product.stock_actual -= int(qty)
                product.save()
            
        return sale