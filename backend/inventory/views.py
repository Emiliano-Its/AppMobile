from rest_framework import viewsets
from .models import RawMaterial, MovimientoInventario
from .serializers import RawMaterialSerializer, MovimientoInventarioSerializer

class RawMaterialViewSet(viewsets.ModelViewSet):
    queryset = RawMaterial.objects.all()
    serializer_class = RawMaterialSerializer

class MovimientoInventarioViewSet(viewsets.ModelViewSet):
    queryset = MovimientoInventario.objects.all().order_by('-fecha')
    serializer_class = MovimientoInventarioSerializer

    def perform_create(self, serializer):
        serializer.save(usuario=self.request.user)
