from django.shortcuts import render
from rest_framework import viewsets
from .models import RawMaterial, MovimientoInventario
from .serializers import RawMaterialSerializer, MovimientoInventarioSerializer

class RawMaterialViewSet(viewsets.ModelViewSet):
    queryset = RawMaterial.objects.all()
    serializer_class = RawMaterialSerializer

class MovimientoInventarioViewSet(viewsets.ModelViewSet):
    queryset = MovimientoInventario.objects.all()
    serializer_class = MovimientoInventarioSerializer