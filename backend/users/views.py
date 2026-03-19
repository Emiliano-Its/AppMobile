from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from .serializers import UserSerializer

class LoginView(APIView):
    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')
        
        user = authenticate(username=username, password=password)
        
        if user:
            serializer = UserSerializer(user)
            # Devolvemos los datos del usuario + un mensaje de éxito
            return Response({
                "message": "Login exitoso",
                "user": serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response({
            "error": "Credenciales inválidas"
        }, status=status.HTTP_401_UNAUTHORIZED)