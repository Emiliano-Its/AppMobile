from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Venta, FinalProduct
from .serializers import FinalProductSerializer, SaleSerializer
from django.db import transaction
from django.contrib.auth import get_user_model

User = get_user_model()

class FinalProductViewSet(viewsets.ModelViewSet):
    """
    Gestiona el inventario de productos finales (tostadas).
    Ruta en router: FinalProduct
    """
    queryset = FinalProduct.objects.all()
    serializer_class = FinalProductSerializer

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        product = self.get_object()
        product.activo = not product.activo
        product.save()
        return Response({'status': 'producto actualizado', 'activo': product.activo})

    # --- BÚSQUEDA POR CÓDIGO ---
    # URL: /api/FinalProduct/buscar_por_codigo/?codigo=XXXX
    @action(detail=False, methods=['get'])
    def buscar_por_codigo(self, request):
        codigo = request.query_params.get('codigo', None)
        
        if not codigo:
            return Response({'error': 'Falta el parámetro codigo'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Buscamos por el campo exacto de tu modelo en Debian
            producto = FinalProduct.objects.get(codigo_barras=codigo)
            serializer = self.get_serializer(producto)
            return Response(serializer.data)
        except FinalProduct.DoesNotExist:
            return Response({'error': 'Producto no encontrado'}, status=status.HTTP_404_NOT_FOUND)

class SaleViewSet(viewsets.ModelViewSet):
    """
    Gestiona las ventas y la lógica de pedidos (descuento de stock).
    Ruta en router: sales
    """
    queryset = Venta.objects.all().order_by('-fecha')
    serializer_class = SaleSerializer

    def perform_create(self, serializer):
        # Asignación automática del vendedor
        if self.request.user.is_authenticated:
            serializer.save(usuario_vendedor=self.request.user)
        else:
            admin = User.objects.filter(is_superuser=True).first()
            if admin:
                serializer.save(usuario_vendedor=admin)
            else:
                serializer.save()

    def get_queryset(self):
        queryset = Venta.objects.all().order_by('-fecha')
        sale_type = self.request.query_params.get('tipo') 
        if sale_type:
            queryset = queryset.filter(tipo=sale_type)
        return queryset
    
    @action(detail=True, methods=['post'])
    def aceptar_pedido(self, request, pk=None):
        """
        Valida stock y lo descuenta al pasar de PEDIDO a ENTREGA.
        """
        venta = self.get_object()
        if venta.tipo != 'PEDIDO':
            return Response({'error': 'Este registro ya no es un pedido pendiente'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # Descontar stock de cada producto en el pedido
                for detalle in venta.detalles.all():
                    producto = detalle.producto
                    if producto.stock_actual < detalle.cantidad:
                        return Response(
                            {'error': f'Stock insuficiente para {producto.nombre}'}, 
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    producto.stock_actual -= detalle.cantidad
                    producto.save()
                
                venta.tipo = 'ENTREGA'
                venta.estado = 'ACEPTADO'
                venta.save()
            return Response({'status': 'Pedido aceptado y stock actualizado'})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    @action(detail=True, methods=['post'])
    def cobrar_entrega(self, request, pk=None):
        venta = self.get_object()
        if venta.tipo != 'ENTREGA':
            return Response({'error': 'Solo se pueden cobrar pedidos en entrega'}, status=status.HTTP_400_BAD_REQUEST)
        
        venta.tipo = 'LOCAL'
        venta.estado = 'ENTREGADO'
        venta.save()
        return Response({'status': 'Pedido cobrado y finalizado'})

    @action(detail=True, methods=['post'])
    def rechazar_pedido(self, request, pk=None):
        venta = self.get_object()
        venta.estado = 'RECHAZADO'
        venta.save()
        return Response({'status': 'Pedido rechazado'})

class POSProductViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Vista simplificada para el Punto de Venta (solo activos y con stock).
    """
    queryset = FinalProduct.objects.filter(stock_actual__gt=0, activo=True)
    serializer_class = FinalProductSerializer