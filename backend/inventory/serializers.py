from rest_framework import serializers
from .models import RawMaterial, MovimientoInventario

class RawMaterialSerializer(serializers.ModelSerializer):
    class Meta:
        model = RawMaterial
        fields = '__all__'

class MovimientoInventarioSerializer(serializers.ModelSerializer):
    # Esto es útil para que en el historial de Flutter aparezca el nombre 
    # de la materia prima en lugar de solo el ID numérico
    materia_prima_nombre = serializers.ReadOnlyField(source='materia_prima.nombre')
    usuario_nombre = serializers.ReadOnlyField(source='usuario.username')

    class Meta:
        model = MovimientoInventario
        fields = [
            'id', 'materia_prima', 'materia_prima_nombre', 
            'tipo', 'cantidad', 'usuario', 'usuario_nombre', 
            'fecha', 'comentario'
        ]