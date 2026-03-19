from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Venta, FinalProduct
from .serializers import FinalProductSerializer, SaleSerializer
from django.db import transaction
from django.contrib.auth import get_user_model

# Obtenemos el modelo de usuario activo en el proyecto (CustomUser)
User = get_user_model()

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

    def perform_create(self, serializer):
        """
        Asigna el usuario vendedor automáticamente.
        """
        if self.request.user.is_authenticated:
            serializer.save(usuario_vendedor=self.request.user)
        else:
            admin = User.objects.filter(is_superuser=True).first()
            if admin:
                serializer.save(usuario_vendedor=admin)
            else:
                raise ValueError("No se encontró un usuario administrador en la base de datos.")

    def get_queryset(self):
        queryset = Venta.objects.all().order_by('-fecha')
        sale_type = self.request.query_params.get('type')
        if sale_type:
            queryset = queryset.filter(tipo=sale_type)
        return queryset
    
    @action(detail=True, methods=['post'])
    def aceptar_pedido(self, request, pk=None):
        """
        Pasa el pedido de PENDIENTE a ACEPTADO y descuenta stock.
        """
        venta = self.get_object()
        
        if venta.tipo != 'PEDIDO':
            return Response(
                {'error': 'Este registro ya no es un pedido pendiente'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                # 1. Descontar del inventario de productos finales
                for detalle in venta.detalles.all():
                    producto = detalle.producto
                    if producto.stock_actual < detalle.cantidad:
                        return Response(
                            {'error': f'No hay suficiente stock de {producto.nombre}'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    producto.stock_actual -= detalle.cantidad
                    producto.save()
                
                # 2. Actualizamos el tipo para lógica interna y el estado para Flutter
                venta.tipo = 'ENTREGA'
                venta.estado = 'ACEPTADO' # <--- CRUCIAL: Esto es lo que lee la app del cliente
                venta.save()
                
            return Response({'status': 'Pedido aceptado y stock actualizado'}, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    @action(detail=True, methods=['post'])
    def cobrar_entrega(self, request, pk=None):
        """
        Finaliza el pedido al ser entregado y pagado.
        """
        venta = self.get_object()
        if venta.tipo != 'ENTREGA':
            return Response({'error': 'Solo se pueden cobrar pedidos en estado de entrega'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Sincronizamos ambos campos
        venta.tipo = 'LOCAL'
        venta.estado = 'ENTREGADO' # <--- Esto hará que en Flutter salga en verde
        venta.save()
        return Response({'status': 'Pedido cobrado y finalizado'}, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def rechazar_pedido(self, request, pk=None):
        """
        Acción para cancelar pedidos (ej. falta de insumos o zona de riesgo).
        """
        venta = self.get_object()
        venta.estado = 'RECHAZADO'
        venta.save()
        return Response({'status': 'Pedido rechazado'})

class POSProductViewSet(viewsets.ReadOnlyModelViewSet):
    """ Viewset para el Punto de Venta (solo productos activos con stock) """
    queryset = FinalProduct.objects.filter(stock_actual__gt=0, activo=True)
    serializer_class = FinalProductSerializer