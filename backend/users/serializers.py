from rest_framework import serializers
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ['id', 'username', 'email', 'rol', 'telefono', 'direccion']
        # No queremos devolver la contraseña por seguridad, pero sí permitir que se envíe al crear usuario
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        # Este método asegura que la contraseña se guarde encriptada (hasheada)
        user = CustomUser.objects.create_user(**validated_data)
        return user