from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Venta,FinalProduct
from .serializers import FinalProductSerializer, SaleSerializer

class FinalProductViewSet(viewsets.ModelViewSet):
    queryset = FinalProduct.objects.all()
    serializer_class = FinalProductSerializer

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        product = self.get_object()
        product.activo = not product.activo
        product.save()
        return Response({'status': 'producto actualizado', 'activo': product.activo})

class SaleViewSet(viewsets.ModelViewSet):
    queryset = Venta.objects.all().order_by('-fecha')
    serializer_class = SaleSerializer

    def get_queryset(self):
        queryset = Venta.objects.all().order_by('-fecha')
        # Filter by type: api/sales/?type=PEDIDO
        sale_type = self.request.query_params.get('type')
        if sale_type:
            queryset = queryset.filter(tipo=sale_type)
        return queryset
    
    @action(detail=True, methods=['post'])
    def completar_pedido(self, request, pk=None):
        venta = self.get_object()
        
        if venta.tipo != "PEDIDO":
            return Response({'error': 'Esta venta ya fue procesada'}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Recorrer los detalles y restar stock
        for detalle in venta.detalles.all():
            producto = detalle.producto
            if producto.stock_actual < detalle.cantidad:
                return Response({
                    'error': f'Stock insuficiente para {producto.nombre}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            producto.stock_actual -= detalle.cantidad
            producto.save()

        # 2. Cambiar el tipo a LOCAL (o venta finalizada)
        venta.tipo = "LOCAL" 
        venta.save()

        return Response({'status': 'Pedido completado y stock actualizado'})

class POSProductViewSet(viewsets.ReadOnlyModelViewSet):
    """ Viewset for the POS to search products quickly """
    queryset = FinalProduct.objects.filter(stock_actual__gt=0)
    serializer_class = FinalProductSerializer   