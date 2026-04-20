from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FinalProductViewSet, SaleViewSet, StatsView

router = DefaultRouter()
router.register(r'sales', SaleViewSet, basename='sale')
router.register(r'FinalProduct', FinalProductViewSet, basename='finalproduct')

urlpatterns = [
    path('', include(router.urls)),
    path('stats/', StatsView.as_view(), name='stats'),
]