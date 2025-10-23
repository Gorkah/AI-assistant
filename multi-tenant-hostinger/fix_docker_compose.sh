#!/bin/bash
# Script de corrección rápida para Docker Compose V2

set -e

echo "=== Fix Docker Compose V2 ==="
echo ""

# Verificar Docker Compose en el host
echo "1. Verificando Docker Compose en el host..."
if ! docker compose version > /dev/null 2>&1; then
    echo "   ❌ Docker Compose V2 no encontrado, instalando..."
    apt-get update
    apt-get install -y docker-compose-plugin
else
    echo "   ✅ Docker Compose V2 disponible"
fi

docker compose version

# Detener panel
echo ""
echo "2. Deteniendo panel..."
cd /srv/AI-assistant/multi-tenant-hostinger
docker compose -f docker-compose.panel.yml stop panel_control

# Reconstruir imagen
echo ""
echo "3. Reconstruyendo imagen del panel..."
cd panel
docker build --no-cache -t nexo-panel:latest .

# Volver y reiniciar
cd ..
echo ""
echo "4. Iniciando panel con nueva imagen..."
docker compose -f docker-compose.panel.yml up -d panel_control

# Esperar
echo ""
echo "5. Esperando a que el panel esté listo..."
sleep 10

# Verificar
echo ""
echo "6. Verificando..."
docker compose -f docker-compose.panel.yml ps panel_control

# Verificar que docker compose funciona dentro del contenedor
echo ""
echo "7. Verificando Docker Compose dentro del contenedor..."
docker exec nexo_panel docker compose version

echo ""
echo "✅ ¡Listo! Intenta crear una instancia ahora."
echo ""
echo "Si sigue fallando, ejecuta:"
echo "  docker compose -f docker-compose.panel.yml logs panel_control"
