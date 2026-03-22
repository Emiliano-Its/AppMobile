from rest_framework import serializers
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    # Definimos explícitamente el password para asegurar que sea de solo escritura
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})

    class Meta:
        model = CustomUser
        # IMPORTANTE: El campo 'password' DEBE estar en la lista de fields
        fields = ['id', 'username', 'email', 'password', 'rol', 'telefono', 'direccion']
        
    def create(self, validated_data):
        """
        Sobrescribimos el método create para usar create_user.
        Esto es VITAL en Django para que la contraseña no se guarde en texto plano,
        sino que se aplique el algoritmo de hashing (PBKDF2).
        """
        # Extraemos los datos validados y usamos create_user del gestor de modelos
        user = CustomUser.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            # Agregamos los campos extra de tu modelo CustomUser
            rol=validated_data.get('rol', 'CLIENTE'),
            telefono=validated_data.get('telefono', ''),
            direccion=validated_data.get('direccion', '')
        )
        return user

    def update(self, instance, validated_data):
        """
        Opcional: Por si decides editar el perfil después. 
        Maneja la actualización de contraseña de forma segura.
        """
        password = validated_data.pop('password', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance