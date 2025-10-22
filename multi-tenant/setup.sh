#!/bin/bash
# ================================================
# NEXO IA - Setup Multi-Tenant System
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP]${NC} $1"; }

log "================================================"
log "   NEXO IA - Sistema Multi-Tenant n8n         "
log "================================================"

# Verificar que estamos en la carpeta correcta
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: Ejecuta este script desde la carpeta multi-tenant/"
    exit 1
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker no está instalado"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose no está instalado"
    exit 1
fi

# Verificar archivo .env
if [ ! -f ".env" ]; then
    log "Creando archivo .env desde template..."
    cp .env.example .env
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Edita el archivo .env con tus configuraciones${NC}"
    echo "Ejecuta: nano .env"
    echo ""
    read -p "Presiona Enter cuando hayas configurado .env..."
fi

# Cargar variables
source .env

# Crear directorios necesarios
log "Creando estructura de directorios..."
mkdir -p instances scripts/{init-db,backups}

# Crear script de init de base de datos
cat > scripts/init-db.sh <<'EOF'
#!/bin/bash
set -e

# Crear base de datos para el panel de control
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE nexo_control;
EOSQL

echo "Base de datos de control creada"
EOF

chmod +x scripts/init-db.sh
chmod +x scripts/provision_instance.sh

# Iniciar servicios base
log "Iniciando servicios base (Traefik, PostgreSQL, Redis)..."
docker-compose up -d traefik postgres redis

log "Esperando a que PostgreSQL esté listo..."
sleep 10

# Iniciar panel de control
log "Iniciando panel de control..."
docker-compose up -d control_panel

# Esperar a que el panel esté listo
log "Esperando a que el panel de control esté listo..."
for i in {1..30}; do
    if docker logs nexo_control_panel 2>&1 | grep -q "Running on"; then
        break
    fi
    sleep 2
done

# Mostrar información
log ""
log "================================================"
log "   ✅ SISTEMA MULTI-TENANT INSTALADO          "
log "================================================"
log ""
log "Panel de Control: https://admin.${BASE_DOMAIN}"
log "Dashboard Traefik: https://traefik.${BASE_DOMAIN}"
log ""
log "Usuario admin: ${PANEL_ADMIN_USER}"
log "Contraseña: ${PANEL_ADMIN_PASSWORD}"
log ""
log "Para crear una instancia:"
log "  ./scripts/provision_instance.sh <cliente> <plan>"
log "Ejemplo:"
log "  ./scripts/provision_instance.sh empresa1 premium"
log ""
log "Comandos útiles:"
log "  docker-compose ps              # Ver estado"
log "  docker-compose logs -f         # Ver logs"
log "  docker-compose down            # Detener todo"
log ""
log "IMPORTANTE:"
log "1. Configura los DNS para apuntar *.${BASE_DOMAIN} a este servidor"
log "2. Asegúrate de que los puertos 80 y 443 estén abiertos"
log ""
