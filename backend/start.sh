#!/bin/bash

echo "Esperando a PostgreSQL..."

until python -c "
import os, psycopg2
try:
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    conn.close()
    print('PostgreSQL listo!')
    exit(0)
except Exception as e:
    print(f'No disponible: {e}')
    exit(1)
"; do
    echo "Reintentando en 3 segundos..."
    sleep 3
done

echo "Corriendo migraciones..."
python manage.py migrate

echo "Recolectando archivos estáticos..."
python manage.py collectstatic --noinput

echo "Iniciando servidor..."
gunicorn myapp.wsgi --bind 0.0.0.0:$PORT
