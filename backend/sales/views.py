from django.shortcuts import render
from rest_framework import viewsets
from .models import FinalProduct
from .serializers import FinalProductSerializer

class FinalProductViewSet(viewsets.ModelViewSet):
    queryset = FinalProduct.objects.all()
    serializer_class = FinalProductSerializer
