from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FinalProductViewSet

router = DefaultRouter()
router.register(r'FinalProduct', FinalProductViewSet)

urlpatterns = [

    path('', include(router.urls)),
]