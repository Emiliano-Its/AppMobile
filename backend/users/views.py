from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from django.contrib.auth import authenticate
from .serializers import UserSerializer

# --- VISTA PARA REGISTRO DE USUARIOS ---
class RegisterView(APIView):
    """
    Maneja la creación de nuevos usuarios (CLIENTES) desde la App.
    """
    permission_classes = [AllowAny]  # Permite que cualquiera acceda para registrarse

    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()  # Esto llama al método create() de tu UserSerializer
            return Response({
                "message": "Usuario registrado exitosamente",
                "user": serializer.data
            }, status=status.HTTP_201_CREATED)
        
        # Si hay errores (usuario ya existe, email inválido, etc.), los devolvemos
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# --- VISTA PARA INICIO DE SESIÓN ---
class LoginView(APIView):
    """
    Autentica al usuario y devuelve sus datos y rol.
    """
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
                serializer = UserSerializer(user)
                return Response({
                    "message": "Login exitoso",
                    "user": serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    "error": "Esta cuenta está desactivada"
                }, status=status.HTTP_403_FORBIDDEN)
        
        return Response({
            "error": "Credenciales inválidas"
        }, status=status.HTTP_401_UNAUTHORIZED)