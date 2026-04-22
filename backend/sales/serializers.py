from rest_framework import serializers
from .models import Venta, DetalleVenta, FinalProduct, MensajePedido


class FinalProductSerializer(serializers.ModelSerializer):
    imagen = serializers.ImageField(required=False, allow_null=True)
    imagen_url = serializers.SerializerMethodField()

    class Meta:
        model = FinalProduct
        fields = ['id', 'codigo_barras', 'nombre', 'precio_venta', 'stock_actual', 'activo', 'imagen', 'imagen_url']

    def get_imagen_url(self, obj):
        if not obj.imagen or not obj.imagen.name:
            return None
        name = obj.imagen.name
        if 'image/upload/' in name:
            name = name.split('image/upload/')[-1]
        if name.startswith('http'):
            return name.replace('https:/res', 'https://res')
        return f"https://res.cloudinary.com/dfaqoztrp/image/upload/{name}"

    def update(self, instance, validated_data):
        request = self.context.get('request')
        if request:
            # CASO 1: Flutter quiere borrar la imagen
            if 'imagen' in request.data and request.data['imagen'] == '':
                if instance.imagen:
                    instance.imagen.delete(save=False)
                instance.imagen = None
            # CASO 2: No viene imagen nueva, mantener la actual
            elif 'imagen' not in request.FILES:
                validated_data.pop('imagen', None)
        validated_data.pop('imagen', None)
        instance.save()
        return super().update(instance, validated_data)


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
