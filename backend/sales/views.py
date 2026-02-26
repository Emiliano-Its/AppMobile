from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.response import Response
from .models import Venta,FinalProduct
from .serializers import FinalProductSerializer, SaleSerializer

class FinalProductViewSet(viewsets.ModelViewSet):
    queryset = FinalProduct.objects.all()
    serializer_class = FinalProductSerializer

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

class POSProductViewSet(viewsets.ReadOnlyModelViewSet):
    """ Viewset for the POS to search products quickly """
    queryset = FinalProduct.objects.filter(stock_actual__gt=0)
    serializer_class = FinalProductSerializer   