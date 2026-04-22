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
        name = obj.imagen.name or ''
        # Si el campo ya tiene una URL completa de Cloudinary guardada
        if name.startswith('http'):
            # Corregir URLs con slash simple (https:/res. -> https://res.)
            if name.startswith('https:/') and not name.startswith('https://'):
                name = 'https://' + name[7:]
            elif name.startswith('http:/') and not name.startswith('http://'):
                name = 'http://' + name[6:]
            return name
        # Path relativo normal — dejar que el storage construya la URL
        try:
            return obj.imagen.url
        except Exception:
            return None


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