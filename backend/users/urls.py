from django.urls import path
from .views import (
    LoginView,
    RegisterView,
    ChangePasswordView,
    UserProfileView,
    UserListView,
    UserDetailView,
)

urlpatterns = [
    path('',                    RegisterView.as_view(),       name='register'),
    path('login/',              LoginView.as_view(),           name='login'),
    path('change-password/',    ChangePasswordView.as_view(),  name='change_password'),
    path('profile/',            UserProfileView.as_view(),     name='user_profile'),
    path('list/',               UserListView.as_view(),        name='user_list'),
    path('<int:pk>/edit/',      UserDetailView.as_view(),      name='user_detail'),
]