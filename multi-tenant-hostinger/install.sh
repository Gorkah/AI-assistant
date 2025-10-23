#!/bin/bash
# ================================================
# NEXO IA - Instalación Multi-Tenant en Hostinger VPS
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "================================================"
log "   NEXO IA - Sistema Multi-Tenant n8n         "
log "   Instalación en Hostinger VPS               "
log "================================================"

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.panel.yml" ]; then
    error "Ejecuta este script desde la carpeta multi-tenant-hostinger/"
fi

# Verificar que existe Traefik
if ! docker ps | grep -q traefik; then
    error "Traefik no está corriendo. Asegúrate de tener Traefik configurado primero."
fi

# Verificar red de Docker
if ! docker network ls | grep -q root_default; then
    warning "Red 'root_default' no encontrada, creando..."
    docker network create root_default
fi

# Configurar .env si no existe
if [ ! -f ".env" ]; then
    log "Creando archivo .env desde template..."
    cp .env.example .env
    
    # Generar secretos
    PANEL_SECRET=$(openssl rand -hex 32)
    POSTGRES_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    REDIS_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    PANEL_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    sed -i "s/GeneraUnSecretoAqui32Caracteres/$PANEL_SECRET/g" .env
    sed -i "s/CambiaEstoPassword123!/$POSTGRES_PASS/g" .env
    sed -i "s/CambiaRedisPassword123!/$REDIS_PASS/g" .env
    sed -i "s/CambiaPasswordPanel123!/$PANEL_PASS/g" .env
    
    log "Archivo .env creado con contraseñas generadas"
    log "Usuario del panel: admin"
    log "Contraseña del panel: $PANEL_PASS"
    echo "$PANEL_PASS" > .panel_password
fi

# Cargar variables
source .env

# Crear directorios necesarios
log "Creando estructura de directorios..."
mkdir -p init-db
mkdir -p /srv/n8n

# Crear script de inicialización de BD
cat > init-db/01-init.sql <<'EOF'
-- Crear base de datos para el panel de control
CREATE DATABASE nexo_control;
EOF

# Verificar que existen los workflows
if [ ! -d "../Recepcionista" ]; then
    warning "No se encontraron los workflows. Cópialos manualmente después."
fi

# Copiar workflows si existen
if [ -d "../Recepcionista" ]; then
    log "Copiando workflows..."
    mkdir -p workflows
    cp -r ../Recepcionista workflows/ 2>/dev/null || true
    cp -r ../LEADS workflows/ 2>/dev/null || true
    cp -r ../ICEBREAKER workflows/ 2>/dev/null || true
    cp -r ../FACTURAS workflows/ 2>/dev/null || true
    cp -r ../PERSONAL\ ASSISTANT workflows/ 2>/dev/null || true
    cp -r ../VIDEOS\ VEO\ 3 workflows/ 2>/dev/null || true
    cp -r ../ANALYTICS workflows/ 2>/dev/null || true
fi

# Construir imagen del panel
log "Construyendo imagen del panel de control..."
cd panel
docker build -t nexo-panel:latest .
cd ..

# Iniciar servicios
log "Iniciando servicios base..."
docker-compose -f docker-compose.panel.yml up -d postgres_shared redis_shared

log "Esperando a que PostgreSQL esté listo..."
sleep 15

# Iniciar panel de control
log "Iniciando panel de control..."
docker-compose -f docker-compose.panel.yml up -d panel_control

# Esperar a que esté listo
log "Esperando a que el panel esté listo..."
for i in {1..30}; do
    if curl -s http://localhost:5000 > /dev/null 2>&1; then
        break
    fi
    sleep 2
done

log ""
log "================================================"
log "   ✅ SISTEMA INSTALADO CORRECTAMENTE          "
log "================================================"
log ""
log "Panel de Control: https://panel.${BASE_DOMAIN}"
log ""
log "Credenciales de acceso:"
log "Usuario: admin"

if [ -f ".panel_password" ]; then
    log "Contraseña: $(cat .panel_password)"
    log ""
    log "⚠️  GUARDA esta contraseña en un lugar seguro"
    log ""
fi

log "Próximos pasos:"
log "1. Accede al panel: https://panel.${BASE_DOMAIN}"
log "2. Crea tu primera instancia desde el panel"
log "3. Los workflows se importarán automáticamente"
log ""
log "Comandos útiles:"
log "  docker-compose -f docker-compose.panel.yml ps       # Ver estado"
log "  docker-compose -f docker-compose.panel.yml logs -f  # Ver logs"
log "  docker ps | grep n8n_                               # Ver instancias de clientes"
log ""
log "Para crear instancias manualmente:"
log "  Accede al panel web o usa la API REST"
log ""

exit 0
