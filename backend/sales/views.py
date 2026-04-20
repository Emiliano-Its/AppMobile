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
class StatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.utils import timezone
        from django.db.models import Sum, Count, Avg, F
        from datetime import timedelta

        hoy = timezone.now().date()
        hace_30 = hoy - timedelta(days=30)
        hace_7  = hoy - timedelta(days=7)

        # ── VENTAS ──────────────────────────────────────────────────────────
        ventas_qs = Venta.objects.filter(estado='ENTREGADO')

        # Totales generales
        total_mes    = ventas_qs.filter(fecha_cobro__date__gte=hace_30).aggregate(t=Sum('total'))['t'] or 0
        total_semana = ventas_qs.filter(fecha_cobro__date__gte=hace_7).aggregate(t=Sum('total'))['t'] or 0
        total_hoy    = ventas_qs.filter(fecha_cobro__date=hoy).aggregate(t=Sum('total'))['t'] or 0

        # Pedidos completados vs cancelados (últimos 30 días)
        pedidos_30  = Venta.objects.filter(fecha__date__gte=hace_30, tipo__in=['PEDIDO','ENTREGA'])
        completados = pedidos_30.filter(estado='ENTREGADO').count()
        cancelados  = pedidos_30.filter(estado='RECHAZADO').count()
        pendientes  = pedidos_30.filter(estado='PENDIENTE').count()

        # Ventas por día (últimos 7 días) para la gráfica de línea
        ventas_por_dia = []
        for i in range(6, -1, -1):
            dia = hoy - timedelta(days=i)
            total_dia = ventas_qs.filter(fecha_cobro__date=dia).aggregate(t=Sum('total'))['t'] or 0
            ventas_por_dia.append({
                'dia': dia.strftime('%d/%m'),
                'total': float(total_dia)
            })

        # ── PRODUCTOS ───────────────────────────────────────────────────────
        # Top 5 productos más vendidos (últimos 30 días)
        from .models import DetalleVenta
        top_productos = (
            DetalleVenta.objects
            .filter(venta__fecha_cobro__date__gte=hace_30, venta__estado='ENTREGADO')
            .values('producto__nombre')
            .annotate(total_vendido=Sum('cantidad'), ingreso=Sum(F('cantidad') * F('precio_unitario')))
            .order_by('-total_vendido')[:5]
        )

        # Productos con stock bajo (menos de 10 unidades y activos)
        stock_bajo = list(
            FinalProduct.objects
            .filter(activo=True, stock_actual__lt=10)
            .values('nombre', 'stock_actual')
            .order_by('stock_actual')
        )

        # ── CLIENTES ────────────────────────────────────────────────────────
        total_clientes = Venta.objects.filter(
            tipo='PEDIDO'
        ).values('cliente_nombre').distinct().count()

        # Cliente más frecuente del mes
        cliente_top = (
            Venta.objects
            .filter(fecha__date__gte=hace_30, estado='ENTREGADO')
            .exclude(cliente_nombre='Venta Mostrador')
            .values('cliente_nombre')
            .annotate(pedidos=Count('id'))
            .order_by('-pedidos')
            .first()
        )

        # Ticket promedio
        ticket_prom = ventas_qs.filter(
            fecha_cobro__date__gte=hace_30
        ).aggregate(avg=Avg('total'))['avg'] or 0

        # ── MATERIA PRIMA ────────────────────────────────────────────────────
        from inventory.models import RawMaterial
        from .models import RegistroProduccion

        # Inventario actual de materias primas
        materias = list(
            RawMaterial.objects.values('nombre', 'stock_actual', 'unidad_medida', 'precio_ultimo_ingreso')
            .order_by('stock_actual')
        )

        # Rendimiento del mes: paquetes producidos por kg/unidad de insumo
        registros_mes = RegistroProduccion.objects.filter(fecha__date__gte=hace_30)

        rendimiento_mes = list(
            registros_mes
            .values('materia_prima__nombre', 'materia_prima__unidad_medida')
            .annotate(
                total_insumo=Sum('cantidad_insumo_usada'),
                total_paquetes=Sum('cantidad_paquetes_producidos'),
                costo_total=Sum('costo_insumo_momento'),
                rendimiento_prom=Avg('rendimiento_calculado'),
            )
            .order_by('-total_paquetes')
        )

        # Convertir Decimal a float para JSON
        for r in rendimiento_mes:
            for k in ['total_insumo', 'costo_total', 'rendimiento_prom']:
                if r[k] is not None:
                    r[k] = round(float(r[k]), 2)

        for m in materias:
            for k in ['stock_actual', 'precio_ultimo_ingreso']:
                if m[k] is not None:
                    m[k] = float(m[k])

        # Histórico semanal de producción (últimas 4 semanas)
        produccion_semanal = []
        for i in range(3, -1, -1):
            inicio = hoy - timedelta(days=(i + 1) * 7)
            fin    = hoy - timedelta(days=i * 7)
            paq = RegistroProduccion.objects.filter(
                fecha__date__gte=inicio, fecha__date__lt=fin
            ).aggregate(t=Sum('cantidad_paquetes_producidos'))['t'] or 0
            produccion_semanal.append({
                'semana': f"S-{i}" if i > 0 else "Esta",
                'paquetes': int(paq),
            })

        # ── CONSEJO DE OPTIMIZACIÓN ─────────────────────────────────────────
        consejo = self._generar_consejo(
            total_semana, total_mes, cancelados, completados,
            stock_bajo, ticket_prom, rendimiento_mes, materias
        )

        return Response({
            # Resumen financiero
            'total_hoy':    round(float(total_hoy), 2),
            'total_semana': round(float(total_semana), 2),
            'total_mes':    round(float(total_mes), 2),
            'ticket_prom':  round(float(ticket_prom), 2),

            # Estado de pedidos
            'completados': completados,
            'cancelados':  cancelados,
            'pendientes':  pendientes,

            # Gráfica de línea
            'ventas_por_dia': ventas_por_dia,

            # Productos
            'top_productos': list(top_productos),
            'stock_bajo':    stock_bajo,

            # Clientes
            'total_clientes': total_clientes,
            'cliente_top':    cliente_top,

            # Materia prima
            'materias_primas':    materias,
            'rendimiento_mes':    rendimiento_mes,
            'produccion_semanal': produccion_semanal,

            # Consejo
            'consejo': consejo,
        })

    def _generar_consejo(self, semana, mes, cancelados, completados, stock_bajo, ticket, rendimiento_mes=None, materias=None):
        semana = float(semana)
        mes    = float(mes)
        ticket = float(ticket)
        consejos = []

        tasa_cancel = (cancelados / max(completados + cancelados, 1)) * 100
        if tasa_cancel > 20:
            consejos.append(f"Tu tasa de cancelación es {tasa_cancel:.0f}%. Considera confirmar disponibilidad con los clientes antes de aceptar pedidos.")

        if stock_bajo:
            nombres = ', '.join([p['nombre'] for p in stock_bajo[:2]])
            consejos.append(f"Stock bajo en: {nombres}. Reabastecer pronto para no perder ventas.")

        if ticket < 100:
            consejos.append("El ticket promedio es bajo. Ofrecer combos o promociones puede aumentar el valor por pedido.")

        if semana > 0 and mes > 0:
            prom_semanal_esperado = mes / 4
            if semana < prom_semanal_esperado * 0.7:
                consejos.append("Esta semana las ventas están por debajo del promedio mensual. Buen momento para promocionar en redes.")

        # Consejos de materia prima
        if rendimiento_mes:
            for r in rendimiento_mes:
                rend = r.get('rendimiento_prom') or 0
                if rend > 0 and rend < 2.0:
                    consejos.append(f"El rendimiento de {r['materia_prima__nombre']} es bajo ({rend:.1f} paq/unidad). Revisa el proceso de producción.")

        if materias:
            sin_stock = [m for m in materias if m['stock_actual'] == 0]
            if sin_stock:
                consejos.append(f"{sin_stock[0]['nombre']} está agotado. Reabastecer es urgente para no detener la producción.")

        if not consejos:
            consejos.append("¡Todo marcha bien! Las ventas están estables. Mantén el ritmo de producción actual.")

        return consejos[0]