from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from .serializers import UserSerializer, ChangePasswordSerializer


# --- VISTA PARA REGISTRO DE USUARIOS ---
class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            token, created = Token.objects.get_or_create(user=user)
            return Response({
                "message": "Usuario registrado exitosamente",
                "token": token.key,
                "user": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- VISTA PARA INICIO DE SESIÓN ---
class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')

        if not username or not password:
            return Response({
                "error": "Por favor, proporcione usuario y contraseña"
            }, status=status.HTTP_400_BAD_REQUEST)

        user = authenticate(username=username, password=password)

        if user is not None:
            if user.is_active:
                token, created = Token.objects.get_or_create(user=user)
                serializer = UserSerializer(user)
                return Response({
                    "message": "Login exitoso",
                    "token": token.key,
                    "user": serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    "error": "Esta cuenta está desactivada"
                }, status=status.HTTP_403_FORBIDDEN)

        return Response({
            "error": "Credenciales inválidas"
        }, status=status.HTTP_401_UNAUTHORIZED)


# --- VISTA PARA CAMBIO DE CONTRASEÑA ---
# FIX CRÍTICO: Después de cambiar la contraseña, Django invalida el token
# anterior. Aquí lo eliminamos y generamos uno nuevo para que Flutter
# no reciba un 401 en las siguientes peticiones.
class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if serializer.is_valid():
            user = request.user

            if not user.check_password(serializer.data.get("old_password")):
                return Response(
                    {"error": "La contraseña actual es incorrecta."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Cambiar contraseña
            user.set_password(serializer.data.get("new_password"))
            user.save()

            # --- REGENERAR TOKEN ---
            # Eliminamos el token viejo (ya inválido tras set_password)
            # y creamos uno nuevo para mantener la sesión activa en Flutter.
            Token.objects.filter(user=user).delete()
            new_token = Token.objects.create(user=user)

            return Response({
                "message": "Contraseña actualizada exitosamente.",
                "token": new_token.key  # Flutter debe guardar este nuevo token
            }, status=status.HTTP_200_OK)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- VISTA PARA PERFIL DE USUARIO ---
# Permite a Flutter guardar/actualizar dirección, teléfono y coordenadas GPS.
class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Devuelve los datos actuales del perfil."""
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """Actualiza dirección, teléfono y coordenadas del usuario."""
        user = request.user

        # Solo actualizamos los campos que vengan en el body
        user.direccion = request.data.get('default_address', user.direccion)
        user.telefono = request.data.get('default_phone', user.telefono)
        user.latitud = request.data.get('last_lat', user.latitud)
        user.longitud = request.data.get('last_lng', user.longitud)
        user.save()

        return Response({
            "message": "Perfil actualizado correctamente.",
            "direccion": user.direccion,
            "telefono": user.telefono,
            "latitud": user.latitud,
            "longitud": user.longitud,
        }, status=status.HTTP_200_OK)