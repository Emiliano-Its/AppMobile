from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True, required=False, style={'input_type': 'password'}
    )

    class Meta:
        model = CustomUser
        # is_active agregado para que el PATCH desde admin_users funcione
        fields = ['id', 'username', 'email', 'password', 'rol',
                  'telefono', 'direccion', 'is_active']

    def create(self, validated_data):
        user = CustomUser.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            rol=validated_data.get('rol', 'CLIENTE'),
            telefono=validated_data.get('telefono', ''),
            direccion=validated_data.get('direccion', ''),
        )
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance


class ChangePasswordSerializer(serializers.Serializer):
    old_password     = serializers.CharField(required=True)
    new_password     = serializers.CharField(required=True, validators=[validate_password])
    confirm_password = serializers.CharField(required=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError(
                {"confirm_password": "Las nuevas contraseñas no coinciden."}
            )
        return attrs