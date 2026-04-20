from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.contrib.auth import authenticate
from rest_framework.authtoken.models import Token
from .serializers import UserSerializer, ChangePasswordSerializer
from .models import CustomUser


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
            return Response({"error": "Por favor, proporcione usuario y contraseña"}, status=status.HTTP_400_BAD_REQUEST)

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
                return Response({"error": "Esta cuenta está desactivada"}, status=status.HTTP_403_FORBIDDEN)

        return Response({"error": "Credenciales inválidas"}, status=status.HTTP_401_UNAUTHORIZED)


# --- VISTA PARA CAMBIO DE CONTRASEÑA ---
class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if serializer.is_valid():
            user = request.user
            if not user.check_password(serializer.data.get("old_password")):
                return Response({"error": "La contraseña actual es incorrecta."}, status=status.HTTP_400_BAD_REQUEST)

            user.set_password(serializer.data.get("new_password"))
            user.save()

            Token.objects.filter(user=user).delete()
            new_token = Token.objects.create(user=user)

            return Response({
                "message": "Contraseña actualizada exitosamente.",
                "token": new_token.key
            }, status=status.HTTP_200_OK)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- VISTA PARA PERFIL DE USUARIO ---
class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data, status=status.HTTP_200_OK)

    def post(self, request):
        user = request.user
        user.direccion = request.data.get('default_address', user.direccion)
        user.telefono  = request.data.get('default_phone',   user.telefono)
        user.latitud   = request.data.get('last_lat',        user.latitud)
        user.longitud  = request.data.get('last_lng',        user.longitud)
        user.save()
        return Response({"message": "Perfil actualizado correctamente."}, status=status.HTTP_200_OK)


# --- VISTA PARA LISTAR TODOS LOS USUARIOS (solo ADMIN/STAFF) ---
class UserListView(APIView):
    permission_classes = [IsAuthenticated]

    def _es_admin(self, user):
        return user.rol in ('ADMIN', 'STAFF')

    def get(self, request):
        if not self._es_admin(request.user):
            return Response({"error": "No tienes permisos."}, status=status.HTTP_403_FORBIDDEN)
        usuarios = CustomUser.objects.all().order_by('date_joined')
        return Response(UserSerializer(usuarios, many=True).data, status=status.HTTP_200_OK)


# --- VISTA PARA EDITAR UN USUARIO POR ID (solo ADMIN/STAFF) ---
class UserDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _es_admin(self, user):
        return user.rol in ('ADMIN', 'STAFF')

    def get_object(self, pk):
        try:
            return CustomUser.objects.get(pk=pk)
        except CustomUser.DoesNotExist:
            return None

    def get(self, request, pk):
        if not self._es_admin(request.user):
            return Response({"error": "No tienes permisos."}, status=status.HTTP_403_FORBIDDEN)
        usuario = self.get_object(pk)
        if not usuario:
            return Response({"error": "Usuario no encontrado."}, status=status.HTTP_404_NOT_FOUND)
        return Response(UserSerializer(usuario).data, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        if not self._es_admin(request.user):
            return Response({"error": "No tienes permisos."}, status=status.HTTP_403_FORBIDDEN)
        usuario = self.get_object(pk)
        if not usuario:
            return Response({"error": "Usuario no encontrado."}, status=status.HTTP_404_NOT_FOUND)

        for campo in ['rol', 'is_active', 'telefono', 'direccion']:
            if campo in request.data:
                setattr(usuario, campo, request.data[campo])
        usuario.save()

        return Response(UserSerializer(usuario).data, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        if not self._es_admin(request.user):
            return Response({"error": "No tienes permisos."}, status=status.HTTP_403_FORBIDDEN)
        usuario = self.get_object(pk)
        if not usuario:
            return Response({"error": "Usuario no encontrado."}, status=status.HTTP_404_NOT_FOUND)
        # Evitar que el admin se elimine a sí mismo
        if usuario.pk == request.user.pk:
            return Response(
                {"error": "No puedes eliminar tu propia cuenta."},
                status=status.HTTP_400_BAD_REQUEST
            )
        usuario.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)