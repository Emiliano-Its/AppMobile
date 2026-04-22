from rest_framework import serializers
from .models import Venta, DetalleVenta, FinalProduct, MensajePedido


class FinalProductSerializer(serializers.ModelSerializer):
    imagen = serializers.ImageField(required=False, allow_null=True)
    imagen_url = serializers.SerializerMethodField()

    class Meta:
        model = FinalProduct
        fields = ['id', 'codigo_barras', 'nombre', 'precio_venta', 'stock_actual', 'activo', 'imagen', 'imagen_url']

    def get_imagen_url(self, obj):
        if not obj.imagen:
            return None
        # Si por alguna razón el nombre ya es una URL completa (legacy o error)
        if obj.imagen.name.startswith('http'):
            return obj.imagen.name.replace('https:/res', 'https://res')
        # Intentar usar la URL generada por el storage de Django
        try:
            url = obj.imagen.url
            # Si la URL no contiene image/upload, inyectarlo
            if 'res.cloudinary.com' in url and 'image/upload/' not in url:
                return url.replace('dfaqoztrp/', 'dfaqoztrp/image/upload/')
            return url
        except Exception:
            # Fallback manual
            return f"https://res.cloudinary.com/dfaqoztrp/image/upload/{obj.imagen.name}"


class SaleDetailSerializer(serializers.ModelSerializer):
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre')

    class Meta:
        model = DetalleVenta
        fields = ['id', 'producto', 'producto_nombre', 'cantidad', 'precio_unitario']


class MensajePedidoSerializer(serializers.ModelSerializer):
    class Meta:
        model = MensajePedido
        fields = ['id', 'venta', 'texto', 'fecha', 'leido']
        read_only_fields = ['fecha']


class SaleSerializer(serializers.ModelSerializer):
    details = SaleDetailSerializer(many=True, source='detalles', required=False)
    seller_name = serializers.ReadOnlyField(source='usuario_vendedor.username', default="Cliente App")
    mensajes = MensajePedidoSerializer(many=True, read_only=True)

    class Meta:
        model = Venta
        fields = [
            'id', 'fecha', 'fecha_cobro', 'tipo', 'total',
            'usuario_vendedor', 'seller_name', 'cliente_nombre',
            'direccion_envio', 'telefono_contacto', 'lat_entrega', 'lng_entrega',
            'fecha_entrega_estimada', 'estado',
            'details', 'mensajes',
        ]
        extra_kwargs = {
            'usuario_vendedor': {'required': False, 'allow_null': True}
        }

    def create(self, validated_data):
        details_data = validated_data.pop('detalles', [])
        sale = Venta.objects.create(**validated_data)

        for detail in details_data:
            product = detail.get('producto')
            qty = detail.get('cantidad')
            price = detail.get('precio_unitario')
            DetalleVenta.objects.create(venta=sale, producto=product, cantidad=qty, precio_unitario=price)

            if sale.tipo == 'LOCAL':
                product.stock_actual -= int(qty)
                if product.stock_actual < 0:
                    product.stock_actual = 0
                if product.stock_actual == 0:
                    product.activo = False
                product.save()

        return sale