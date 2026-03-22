from django.urls import path
from .views import LoginView, RegisterView # <--- Asegúrate de importar la nueva vista

urlpatterns = [
    # Ruta para iniciar sesión: /api/users/login/
    path('login/', LoginView.as_view(), name='login'),
    
    # Ruta para registrarse: /api/users/
    # Esta es la que resuelve el error 404 que tenías
    path('', RegisterView.as_view(), name='register'),
]