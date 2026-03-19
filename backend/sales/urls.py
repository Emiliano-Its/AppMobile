from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FinalProductViewSet, SaleViewSet

router = DefaultRouter()
router.register(r'sales', SaleViewSet, basename='sale')
router.register(r'FinalProduct', FinalProductViewSet)

urlpatterns = [

    path('', include(router.urls)),
    path('api/', include(router.urls))
]