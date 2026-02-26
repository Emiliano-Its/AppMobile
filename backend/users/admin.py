from django.contrib import admin

# Register your models here.
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser

class CustomUserAdmin(UserAdmin):
    # This adds your custom fields to the User edit page in Admin
    fieldsets = UserAdmin.fieldsets + (
        ('Información Adicional', {'fields': ('telefono', 'direccion', 'rol')}),
    )
    # This adds the columns to the User list page
    list_display = ['username', 'email', 'rol', 'is_staff']

admin.site.register(CustomUser, CustomUserAdmin)