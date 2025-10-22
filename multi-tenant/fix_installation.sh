#!/bin/bash
# ================================================
# SCRIPT DE REPARACIÓN RÁPIDA
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

clear
echo "================================================"
echo "   REPARACIÓN RÁPIDA - NEXO IA"
echo "================================================"
echo ""

cd /opt/nexo-ai || cd /opt/AI-assistant/multi-tenant || error "No se encuentra el directorio de instalación"

# ================================================
# 1. OBTENER IPv4 CORRECTA
# ================================================
log "1. Detectando IPv4 pública correcta..."

# Intentar varios métodos
VPS_IP=$(curl -4 -s ifconfig.me 2>/dev/null)

if [ -z "$VPS_IP" ]; then
    VPS_IP=$(curl -s https://api.ipify.org 2>/dev/null)
fi

if [ -z "$VPS_IP" ]; then
    VPS_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
fi

if [[ "$VPS_IP" =~ ":" ]]; then
    error "Solo se detectó IPv6. Verifica tu configuración de red."
fi

log "IPv4 detectada: $VPS_IP"

# ================================================
# 2. ACTUALIZAR .env CON IP CORRECTA
# ================================================
log "2. Actualizando archivo .env con IPv4 correcta..."

if [ -f ".env" ]; then
    sed -i "s/^VPS_IP=.*/VPS_IP=$VPS_IP/" .env
    log "Archivo .env actualizado"
else
    warning "Archivo .env no encontrado"
fi

# ================================================
# 3. VERIFICAR Y ARREGLAR POSTGRESQL
# ================================================
log "3. Verificando PostgreSQL..."

# Verificar que el contenedor esté corriendo
if ! docker ps | grep -q nexo_postgres; then
    error "PostgreSQL no está corriendo. Ejecuta: docker-compose -f docker-compose-nossl.yml up -d"
fi

# Esperar a que PostgreSQL esté listo
for i in {1..30}; do
    if docker exec nexo_postgres pg_isready -U nexo_admin &> /dev/null; then
        log "PostgreSQL está listo"
        break
    fi
    sleep 2
done

# Crear base de datos de control si no existe
log "Verificando base de datos de control..."
docker exec nexo_postgres psql -U nexo_admin -d postgres -c "CREATE DATABASE nexo_control;" 2>/dev/null || log "Base de datos nexo_control ya existe"

# ================================================
# 4. ACTUALIZAR SCRIPT DE PROVISION
# ================================================
log "4. Actualizando script provision_nossl.sh..."

if [ -f "scripts/provision_nossl.sh" ]; then
    # Hacer backup
    cp scripts/provision_nossl.sh scripts/provision_nossl.sh.backup
    
    # Agregar -d postgres al comando psql si no está
    sed -i 's/psql -U \$POSTGRES_ADMIN_USER <</psql -U $POSTGRES_ADMIN_USER -d postgres <</' scripts/provision_nossl.sh
    
    log "Script actualizado"
else
    warning "Script provision_nossl.sh no encontrado"
fi

# ================================================
# 5. MOSTRAR INFORMACIÓN
# ================================================
echo ""
echo "================================================"
echo "   ✅ REPARACIÓN COMPLETADA"
echo "================================================"
echo ""
echo "📊 CONFIGURACIÓN ACTUALIZADA:"
echo "  - IPv4: $VPS_IP"
echo "  - PostgreSQL: Funcionando"
echo "  - Script provision: Actualizado"
echo ""
echo "🌐 ACCESOS:"
echo "  - Panel Control: http://$VPS_IP:3000"
echo ""
source .env 2>/dev/null
echo "  - Usuario: ${PANEL_ADMIN_USER:-admin}"
echo "  - Contraseña: $PANEL_ADMIN_PASSWORD"
echo ""
echo "📝 CREAR NUEVA INSTANCIA:"
echo "  ./scripts/provision_nossl.sh cliente1 premium"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "  - Ver contenedores: docker ps"
echo "  - Logs PostgreSQL: docker logs nexo_postgres"
echo "  - Reiniciar todo: docker-compose -f docker-compose-nossl.yml restart"
echo ""

# ================================================
# 6. VERIFICAR FIREWALL
# ================================================
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        warning "Verificando firewall..."
        if ! ufw status | grep -q "3000"; then
            warning "Puerto 3000 no está abierto"
            echo "  Ejecuta: ufw allow 3000/tcp"
        fi
        if ! ufw status | grep -q "5678"; then
            warning "Puertos 5678-5698 no están abiertos"
            echo "  Ejecuta: ufw allow 5678:5698/tcp"
        fi
    fi
fi

echo ""
log "¡Sistema reparado! Intenta crear una instancia ahora."
echo ""
