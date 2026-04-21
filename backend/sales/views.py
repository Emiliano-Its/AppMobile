from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Venta, FinalProduct
from .serializers import FinalProductSerializer, SaleSerializer
from django.db import transaction
from django.contrib.auth import get_user_model

User = get_user_model()

class FinalProductViewSet(viewsets.ModelViewSet):
    """
    Gestiona el inventario de productos finales (tostadas).
    Ruta en router: FinalProduct
    """
    queryset = FinalProduct.objects.all()
    serializer_class = FinalProductSerializer

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        product = self.get_object()
        product.activo = not product.activo
        product.save()
        return Response({'status': 'producto actualizado', 'activo': product.activo})

    # --- BÚSQUEDA POR CÓDIGO ---
    # URL: /api/FinalProduct/buscar_por_codigo/?codigo=XXXX
    @action(detail=False, methods=['get'])
    def buscar_por_codigo(self, request):
        codigo = request.query_params.get('codigo', None)
        
        if not codigo:
            return Response({'error': 'Falta el parámetro codigo'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Buscamos por el campo exacto de tu modelo en Debian
            producto = FinalProduct.objects.get(codigo_barras=codigo)
            serializer = self.get_serializer(producto)
            return Response(serializer.data)
        except FinalProduct.DoesNotExist:
            return Response({'error': 'Producto no encontrado'}, status=status.HTTP_404_NOT_FOUND)

class SaleViewSet(viewsets.ModelViewSet):
    """
    Gestiona las ventas y la lógica de pedidos (descuento de stock).
    Ruta en router: sales
    """
    queryset = Venta.objects.all().order_by('-fecha')
    serializer_class = SaleSerializer

    def perform_create(self, serializer):
        from django.utils import timezone
        extra = {}
        # Las ventas de mostrador se cobran en el momento, registramos fecha_cobro ya
        if self.request.data.get('tipo') == 'LOCAL':
            extra['fecha_cobro'] = timezone.now()

        if self.request.user.is_authenticated:
            serializer.save(usuario_vendedor=self.request.user, **extra)
        else:
            admin = User.objects.filter(is_superuser=True).first()
            if admin:
                serializer.save(usuario_vendedor=admin, **extra)
            else:
                serializer.save(**extra)

    def get_queryset(self):
        queryset = Venta.objects.all().order_by('-fecha')
        sale_type = self.request.query_params.get('tipo')
        estado = self.request.query_params.get('estado')
        if sale_type:
            queryset = queryset.filter(tipo=sale_type)
        if estado:
            queryset = queryset.filter(estado=estado)
        # Por defecto excluimos RECHAZADO cuando se filtra por tipo
        # para que los cancelados no aparezcan en las listas activas
        elif sale_type:
            queryset = queryset.exclude(estado='RECHAZADO')
        return queryset
    
    @action(detail=True, methods=['post'])
    def aceptar_pedido(self, request, pk=None):
        """
        Valida stock y lo descuenta al pasar de PEDIDO a ENTREGA.
        """
        venta = self.get_object()
        if venta.tipo != 'PEDIDO':
            return Response({'error': 'Este registro ya no es un pedido pendiente'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # Descontar stock de cada producto en el pedido
                for detalle in venta.detalles.all():
                    producto = detalle.producto
                    if producto.stock_actual < detalle.cantidad:
                        return Response(
                            {'error': f'Stock insuficiente para {producto.nombre}'}, 
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    producto.stock_actual -= detalle.cantidad
                    producto.save()
                
                venta.tipo = 'ENTREGA'
                venta.estado = 'ACEPTADO'
                venta.save()
            return Response({'status': 'Pedido aceptado y stock actualizado'})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    @action(detail=True, methods=['post'])
    def cobrar_entrega(self, request, pk=None):
        venta = self.get_object()
        if venta.tipo != 'ENTREGA':
            return Response({'error': 'Solo se pueden cobrar pedidos en entrega'}, status=status.HTTP_400_BAD_REQUEST)
        
        from django.utils import timezone
        venta.tipo = 'LOCAL'
        venta.estado = 'ENTREGADO'
        venta.fecha_cobro = timezone.now()  # Fecha real del cobro
        venta.save()
        return Response({'status': 'Pedido cobrado y finalizado'})

    @action(detail=True, methods=['post'])
    def rechazar_pedido(self, request, pk=None):
        venta = self.get_object()
        venta.estado = 'RECHAZADO'
        venta.save()
        return Response({'status': 'Pedido rechazado'})

    @action(detail=True, methods=['post'])
    def cancelar_pedido(self, request, pk=None):
        """
        Cancela el pedido y restaura el stock si ya había sido descontado
        (es decir, si el pedido estaba en tipo ENTREGA).
        """
        venta = self.get_object()

        if venta.estado in ('ENTREGADO', 'RECHAZADO'):
            return Response(
                {'error': 'No se puede cancelar un pedido ya finalizado.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                # Solo restauramos stock si ya fue descontado (tipo ENTREGA)
                if venta.tipo == 'ENTREGA':
                    for detalle in venta.detalles.all():
                        producto = detalle.producto
                        producto.stock_actual += detalle.cantidad
                        # Si tenía stock 0 y estaba inactivo, lo reactivamos
                        if not producto.activo:
                            producto.activo = True
                        producto.save()

                venta.estado = 'RECHAZADO'
                venta.save()

            return Response({'status': 'Pedido cancelado y stock restaurado'})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def enviar_mensaje(self, request, pk=None):
        """Envía un mensaje del vendedor al cliente sobre su pedido."""
        from .models import MensajePedido
        from .serializers import MensajePedidoSerializer
        venta = self.get_object()
        texto = request.data.get('texto', '').strip()

        if not texto:
            return Response({'error': 'El mensaje no puede estar vacío.'}, status=status.HTTP_400_BAD_REQUEST)

        mensaje = MensajePedido.objects.create(venta=venta, texto=texto)
        return Response(MensajePedidoSerializer(mensaje).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def marcar_mensajes_leidos(self, request, pk=None):
        """Marca todos los mensajes del pedido como leídos (llama el cliente)."""
        from .models import MensajePedido
        venta = self.get_object()
        MensajePedido.objects.filter(venta=venta, leido=False).update(leido=True)
        return Response({'status': 'Mensajes marcados como leídos'})

class POSProductViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Vista simplificada para el Punto de Venta (solo activos y con stock).
    """
    queryset = FinalProduct.objects.filter(stock_actual__gt=0, activo=True)
    serializer_class = FinalProductSerializer

# --- ENDPOINT DE ESTADÍSTICAS PARA ADMIN ---

# --- ENDPOINT DE ESTADÍSTICAS PARA ADMIN ---
class StatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.utils import timezone
        from django.db.models import Sum, Count, Avg, F, Q
        from datetime import timedelta
        from inventory.models import RawMaterial, MovimientoInventario
        from .models import DetalleVenta

        hoy    = timezone.now().date()
        # Período según parámetro: semana / mes / año (default: mes)
        periodo = request.query_params.get('periodo', 'mes')
        if periodo == 'semana':
            desde = hoy - timedelta(days=7)
        elif periodo == 'año':
            desde = hoy.replace(month=1, day=1)
        else:  # mes
            desde = hoy - timedelta(days=30)

        hace_7 = hoy - timedelta(days=7)

        # ── VENTAS COBRADAS ──────────────────────────────────────────────────
        # Usamos fecha_cobro si existe, sino fecha (para ventas antiguas sin fecha_cobro)
        from django.db.models import Q
        ventas_qs = Venta.objects.filter(
            estado='ENTREGADO'
        ).filter(
            Q(fecha_cobro__date__gte=desde) | Q(fecha_cobro__isnull=True, fecha__date__gte=desde)
        )

        total_periodo = ventas_qs.aggregate(t=Sum('total'))['t'] or 0
        total_hoy = Venta.objects.filter(
            estado='ENTREGADO'
        ).filter(
            Q(fecha_cobro__date=hoy) | Q(fecha_cobro__isnull=True, fecha__date=hoy)
        ).aggregate(t=Sum('total'))['t'] or 0
        ticket_prom = ventas_qs.aggregate(avg=Avg('total'))['avg'] or 0

        # Ventas por día (últimos 7 días)
        ventas_por_dia = []
        for i in range(6, -1, -1):
            dia = hoy - timedelta(days=i)
            t = Venta.objects.filter(estado='ENTREGADO').filter(
                Q(fecha_cobro__date=dia) | Q(fecha_cobro__isnull=True, fecha__date=dia)
            ).aggregate(t=Sum('total'))['t'] or 0
            ventas_por_dia.append({'dia': dia.strftime('%d/%m'), 'total': round(float(t), 2)})

        # ── ESTADO DE PEDIDOS ────────────────────────────────────────────────
        todos_periodo = Venta.objects.filter(fecha__date__gte=desde)

        # Solo contamos pedidos reales (no ventas de mostrador LOCAL)
        completados = todos_periodo.filter(estado='ENTREGADO', tipo='LOCAL').exclude(cliente_nombre='Venta Mostrador').count()
        # Ventas mostrador también son "entregadas" pero las separamos
        mostrador   = todos_periodo.filter(estado='ENTREGADO', cliente_nombre='Venta Mostrador').count()
        pendientes  = todos_periodo.filter(estado='PENDIENTE', tipo='PEDIDO').count()
        cancelados  = todos_periodo.filter(estado='RECHAZADO').count()
        en_camino   = todos_periodo.filter(estado='ACEPTADO').count()
        # Total entregados = cobrados a domicilio + mostrador
        completados = completados + mostrador

        # ── TOP PRODUCTOS ────────────────────────────────────────────────────
        top_productos = list(
            DetalleVenta.objects
            .filter(venta__estado='ENTREGADO')
            .filter(
                Q(venta__fecha_cobro__date__gte=desde) |
                Q(venta__fecha_cobro__isnull=True, venta__fecha__date__gte=desde)
            )
            .values('producto__nombre')
            .annotate(
                total_vendido=Sum('cantidad'),
                ingreso=Sum(F('cantidad') * F('precio_unitario'))
            )
            .order_by('-total_vendido')[:5]
        )
        for p in top_productos:
            if p['ingreso'] is not None:
                p['ingreso'] = round(float(p['ingreso']), 2)

        # ── STOCK BAJO ───────────────────────────────────────────────────────
        stock_bajo = list(
            FinalProduct.objects
            .filter(activo=True, stock_actual__lt=10)
            .values('nombre', 'stock_actual')
            .order_by('stock_actual')
        )

        # ── CLIENTES ────────────────────────────────────────────────────────
        total_clientes = Venta.objects.exclude(cliente_nombre='Venta Mostrador').values('cliente_nombre').distinct().count()
        cliente_top = (
            Venta.objects
            .filter(fecha__date__gte=desde, estado='ENTREGADO')
            .exclude(cliente_nombre='Venta Mostrador')
            .values('cliente_nombre')
            .annotate(pedidos=Count('id'))
            .order_by('-pedidos')
            .first()
        )

        # ── INVENTARIO MATERIA PRIMA ─────────────────────────────────────────
        materias = []
        for mp in RawMaterial.objects.all().order_by('stock_actual'):
            stock = float(mp.stock_actual)
            precio = float(mp.precio_ultimo_ingreso)
            materias.append({
                'nombre': mp.nombre,
                # Entero si no tiene decimales
                'stock_actual': int(stock) if stock == int(stock) else round(stock, 2),
                'unidad_medida': mp.unidad_medida,
                'precio_ultimo_ingreso': round(precio, 2),
            })

        # ── RENDIMIENTO POR MATERIA PRIMA ────────────────────────────────────
        # Usa MovimientoInventario si existen, si no muestra solo entradas/salidas del stock
        rendimiento_mp = []
        total_ventas_periodo = float(total_periodo)

        for mp in RawMaterial.objects.all():
            entradas = MovimientoInventario.objects.filter(
                materia_prima=mp, tipo='ENTRADA', fecha__date__gte=desde
            ).aggregate(t=Sum('cantidad'))['t'] or 0

            salidas = MovimientoInventario.objects.filter(
                materia_prima=mp, tipo__in=['SALIDA', 'PRODUCCION'], fecha__date__gte=desde
            ).aggregate(t=Sum('cantidad'))['t'] or 0

            entrada_f = float(entradas)
            salida_f  = float(salidas)
            stock_f   = float(mp.stock_actual)
            precio_f  = float(mp.precio_ultimo_ingreso)

            # Si hay movimientos registrados, calcular rendimiento real
            # Si no, mostrar de todas formas con datos de stock e inversión estimada
            costo_entrada = round(entrada_f * precio_f, 2) if entrada_f > 0 else 0

            # Rendimiento: $ ventas / unidades usadas (salidas)
            rendimiento = round(total_ventas_periodo / salida_f, 2) if salida_f > 0 else None

            # Siempre incluir la materia prima si tiene stock o tuvo movimientos
            if entrada_f > 0 or salida_f > 0 or stock_f > 0:
                rendimiento_mp.append({
                    'nombre': mp.nombre,
                    'unidad': mp.unidad_medida,
                    'entradas': int(entrada_f) if entrada_f == int(entrada_f) else round(entrada_f, 2),
                    'salidas':  int(salida_f)  if salida_f  == int(salida_f)  else round(salida_f, 2),
                    'stock_actual': int(stock_f) if stock_f == int(stock_f) else round(stock_f, 2),
                    'costo_entrada': costo_entrada,
                    'rendimiento_por_unidad': rendimiento,
                })

        return Response({
            'periodo': periodo,
            # Financiero
            'total_hoy':     round(float(total_hoy), 2),
            'total_periodo': round(float(total_periodo), 2),
            'ticket_prom':   round(float(ticket_prom), 2),
            # Gráfica
            'ventas_por_dia': ventas_por_dia,
            # Pedidos
            'completados': completados,
            'pendientes':  pendientes,
            'cancelados':  cancelados,
            'en_camino':   en_camino,
            # Productos
            'top_productos': top_productos,
            'stock_bajo':    stock_bajo,
            # Clientes
            'total_clientes': total_clientes,
            'cliente_top':    cliente_top,
            # Materia prima
            'materias_primas':  materias,
            'rendimiento_mp':   rendimiento_mp,
        })