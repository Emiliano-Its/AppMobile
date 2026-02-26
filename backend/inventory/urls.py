from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RawMaterialViewSet, MovimientoInventarioViewSet

router = DefaultRouter()
router.register(r'raw-materials', RawMaterialViewSet)
router.register(r'inventory-movements', MovimientoInventarioViewSet)

urlpatterns = [
    path('', include(router.urls)),
]