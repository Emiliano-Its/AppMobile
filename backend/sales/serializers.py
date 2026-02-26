from rest_framework import serializers
from .models import FinalProduct


#translate between django and Flutter
class FinalProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = FinalProduct
        fields = '__all__' 