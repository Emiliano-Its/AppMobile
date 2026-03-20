from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FinalProductViewSet, SaleViewSet

# Creamos el router
router = DefaultRouter()

# 1. Registramos 'sales'
router.register(r'sales', SaleViewSet, basename='sale')

# 2. Registramos 'FinalProduct'
router.register(r'FinalProduct', FinalProductViewSet, basename='finalproduct')

urlpatterns = [
    # USAMOS CADENA VACÍA '' 
    # Para que las rutas sean /api/sales/ y /api/FinalProduct/
    # y NO /api/api/FinalProduct/
    path('', include(router.urls)),
]