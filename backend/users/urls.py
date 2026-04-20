from django.urls import path
from .views import LoginView, RegisterView, ChangePasswordView, UserProfileView

urlpatterns = [
    # Registro: POST /api/users/
    path('', RegisterView.as_view(), name='register'),

    # Login: POST /api/users/login/
    path('login/', LoginView.as_view(), name='login'),

    # Cambio de contraseña: POST /api/users/change-password/
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),

    # Perfil: GET y POST /api/users/profile/
    path('profile/', UserProfileView.as_view(), name='user_profile'),
]