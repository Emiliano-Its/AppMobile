"""
URL configuration for myapp project (Tostadería el Molino).
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # --- APP DE USUARIOS ---
    # Esto resuelve: /api/users/ (Registro) y /api/users/login/ (Login)
    path('api/users/', include('users.urls')),
    
    # --- APP DE INVENTARIO (PRODUCTOS) ---
    # Al dejarlo así, las rutas dentro de inventory/urls.py 
    # empezarán directamente después de /api/
    # Ejemplo: /api/FinalProduct/
    path('api/', include('inventory.urls')),
    
    # --- APP DE VENTAS ---
    # Ejemplo: /api/sales/
    path('api/', include('sales.urls')),
]

# --- SERVIR ARCHIVOS MEDIA (FOTOS DE PRODUCTOS) ---
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
