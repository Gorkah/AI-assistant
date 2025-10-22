#!/bin/bash
# ================================================
# INSTALACIÓN AUTOMÁTICA - HOSTINGER SIN DOMINIO
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║    ███╗   ██╗███████╗██╗  ██╗ ██████╗      █████╗ ██╗     ║
║    ████╗  ██║██╔════╝╚██╗██╔╝██╔═══██╗    ██╔══██╗██║     ║
║    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║    ███████║██║     ║
║    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║    ██╔══██║██║     ║
║    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝    ██║  ██║██║     ║
║    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝     ╚═╝  ╚═╝╚═╝     ║
║                                                            ║
║           Sistema Multi-Tenant para n8n                   ║
║              Instalación en Hostinger                     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }

echo ""
log "Iniciando instalación..."
echo ""

# ================================================
# VERIFICAR PERMISOS
# ================================================
if [ "$EUID" -ne 0 ]; then 
    error "Este script debe ejecutarse como root. Usa: sudo bash install_hostinger.sh"
fi

# ================================================
# DETECTAR SISTEMA OPERATIVO
# ================================================
log "Detectando sistema operativo..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    log "Sistema: $OS $VER"
else
    error "No se pudo detectar el sistema operativo"
fi

# ================================================
# OBTENER IP PÚBLICA
# ================================================
log "Obteniendo IP pública del VPS..."
VPS_IP=$(curl -s ifconfig.me)
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(hostname -I | awk '{print $1}')
fi
log "IP detectada: $VPS_IP"

# ================================================
# LIMPIAR INSTALACIÓN ANTERIOR
# ================================================
echo ""
warning "¿Deseas limpiar cualquier instalación anterior de Docker? (s/N)"
read -p "Respuesta: " CLEAN_DOCKER

if [[ "$CLEAN_DOCKER" =~ ^[Ss]$ ]]; then
    log "Limpiando contenedores anteriores..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    docker system prune -a -f 2>/dev/null || true
    log "Limpieza completada"
fi

# ================================================
# INSTALAR DOCKER
# ================================================
echo ""
log "Verificando Docker..."

if ! command -v docker &> /dev/null; then
    log "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log "Docker instalado"
else
    log "Docker ya está instalado"
fi

# ================================================
# INSTALAR DOCKER COMPOSE
# ================================================
log "Verificando Docker Compose..."

if ! command -v docker-compose &> /dev/null; then
    log "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "Docker Compose instalado"
else
    log "Docker Compose ya está instalado"
fi

# Verificar versiones
DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | tr -d ',')
log "Docker: $DOCKER_VERSION | Docker Compose: $COMPOSE_VERSION"

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
log "Instalando dependencias..."
apt-get update -qq
apt-get install -y -qq git curl wget jq net-tools ufw 2>/dev/null
log "Dependencias instaladas"

# ================================================
# CONFIGURAR FIREWALL
# ================================================
echo ""
warning "¿Deseas configurar el firewall automáticamente? (S/n)"
read -p "Respuesta: " SETUP_FIREWALL

if [[ ! "$SETUP_FIREWALL" =~ ^[Nn]$ ]]; then
    log "Configurando firewall..."
    
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment "SSH"
    ufw allow 3000/tcp comment "Panel Control"
    ufw allow 5678:5698/tcp comment "n8n Instances"
    
    log "Firewall configurado"
    ufw status
else
    warning "Recuerda abrir los puertos manualmente:"
    echo "  - Puerto 22 (SSH)"
    echo "  - Puerto 3000 (Panel)"
    echo "  - Puertos 5678-5698 (n8n)"
fi

# ================================================
# CONFIGURAR DIRECTORIO
# ================================================
echo ""
log "Configurando directorio de instalación..."

INSTALL_DIR="/opt/nexo-ai"

if [ -d "$INSTALL_DIR" ]; then
    warning "El directorio $INSTALL_DIR ya existe"
    warning "¿Deseas eliminarlo y hacer instalación limpia? (s/N)"
    read -p "Respuesta: " CLEAN_DIR
    
    if [[ "$CLEAN_DIR" =~ ^[Ss]$ ]]; then
        rm -rf "$INSTALL_DIR"
        log "Directorio eliminado"
    fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ================================================
# CREAR ESTRUCTURA
# ================================================
log "Creando estructura de directorios..."
mkdir -p instances scripts control-panel/templates logs

# ================================================
# CREAR ARCHIVOS NECESARIOS
# ================================================
log "Generando archivos de configuración..."

# ================================================
# CONFIGURAR VARIABLES DE ENTORNO
# ================================================
echo ""
log "Configurando variables de entorno..."

cat > .env <<EOF
# ================================================
# NEXO IA - Configuración Multi-Tenant (SIN SSL)
# Generado automáticamente: $(date)
# ================================================

# IP Pública del VPS
VPS_IP=$VPS_IP

# POSTGRESQL
POSTGRES_ADMIN_USER=nexo_admin
POSTGRES_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# REDIS
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# PANEL DE CONTROL
PANEL_SECRET_KEY=$(openssl rand -base64 32)
PANEL_ADMIN_USER=admin
PANEL_ADMIN_PASSWORD=$(openssl rand -base64 16)

# PUERTOS
BASE_PORT=5678

# CONFIGURACIÓN n8n
DEFAULT_N8N_VERSION=latest
DEFAULT_TIMEZONE=Europe/Madrid

# LÍMITES
MAX_INSTANCES=20
EOF

log "Archivo .env creado"

# ================================================
# CREAR DOCKER-COMPOSE
# ================================================
log "Creando docker-compose-nossl.yml..."

cat > docker-compose-nossl.yml <<'DOCKEREOF'
version: '3.8'

networks:
  nexo_network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:

services:
  postgres:
    image: postgres:15-alpine
    container_name: nexo_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_ADMIN_USER:-nexo_admin}
      POSTGRES_PASSWORD: ${POSTGRES_ADMIN_PASSWORD:-ChangeThisPassword123!}
      POSTGRES_DB: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - nexo_network
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_ADMIN_USER:-nexo_admin}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: nexo_redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:-RedisPassword123!}
    volumes:
      - redis_data:/data
    networks:
      - nexo_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
DOCKEREOF

log "docker-compose-nossl.yml creado"

# ================================================
# CREAR SCRIPT DE APROVISIONAMIENTO
# ================================================
log "Creando script de aprovisionamiento..."

cat > scripts/provision_nossl.sh <<'PROVEOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

[ $# -lt 2 ] && error "Uso: $0 <cliente_id> <plan>"

CLIENT_ID=$1
PLAN=$2

[[ ! $CLIENT_ID =~ ^[a-z0-9-]+$ ]] && error "cliente_id inválido"
[[ ! $PLAN =~ ^(estandar|premium|nexa)$ ]] && error "Plan: estandar|premium|nexa"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTANCES_DIR="$PROJECT_ROOT/instances"

source "$PROJECT_ROOT/.env"

[ -d "$INSTANCES_DIR/$CLIENT_ID" ] && error "Instancia ya existe"

log "Creando instancia: $CLIENT_ID - Plan: $PLAN"

CURRENT_INSTANCES=$(ls -1 "$INSTANCES_DIR" 2>/dev/null | wc -l)
ASSIGNED_PORT=$((BASE_PORT + CURRENT_INSTANCES))

CLIENT_DIR="$INSTANCES_DIR/$CLIENT_ID"
mkdir -p "$CLIENT_DIR"/{data,workflows,backups,logs}

DB_NAME="n8n_${CLIENT_ID//-/_}"
DB_USER="n8n_${CLIENT_ID//-/_}"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)

log "Puerto: $ASSIGNED_PORT | Creando BD..."

docker exec nexo_postgres psql -U $POSTGRES_ADMIN_USER <<-EOSQL
    CREATE DATABASE $DB_NAME;
    CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL

cat > "$CLIENT_DIR/.env" <<EOF
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_EDITOR_BASE_URL=http://${VPS_IP}:${ASSIGNED_PORT}
WEBHOOK_URL=http://${VPS_IP}:${ASSIGNED_PORT}

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=$DB_NAME
DB_POSTGRESDB_USER=$DB_USER
DB_POSTGRESDB_PASSWORD=$DB_PASSWORD

N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$BASIC_AUTH_PASSWORD

EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
GENERIC_TIMEZONE=${DEFAULT_TIMEZONE}
EOF

cat > "$CLIENT_DIR/docker-compose.yml" <<DEOF
version: '3.8'
networks:
  nexo_network:
    external: true
services:
  n8n_${CLIENT_ID}:
    image: n8nio/n8n:latest
    container_name: n8n_${CLIENT_ID}
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./data:/home/node/.n8n
      - ./workflows:/workflows
    networks:
      - nexo_network
    ports:
      - "${ASSIGNED_PORT}:5678"
DEOF

log "Iniciando contenedor..."
cd "$CLIENT_DIR"
docker-compose up -d

log "Esperando n8n..."
for i in {1..30}; do
    if curl -s "http://localhost:${ASSIGNED_PORT}" | grep -q "n8n" 2>/dev/null; then
        break
    fi
    sleep 2
done

cat > "$CLIENT_DIR/manage.sh" <<'MANEOF'
#!/bin/bash
case $1 in
    start) docker-compose up -d ;;
    stop) docker-compose down ;;
    restart) docker-compose restart ;;
    logs) docker-compose logs -f --tail=100 ;;
    status) docker-compose ps ;;
    backup) tar -czf "backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz" data/ ;;
    *) echo "Uso: $0 {start|stop|restart|logs|status|backup}" ;;
esac
MANEOF

chmod +x "$CLIENT_DIR/manage.sh"

echo ""
log "================================================"
log "   ✅ INSTANCIA CREADA"
log "================================================"
log ""
log "Cliente: $CLIENT_ID"
log "Plan: $PLAN"
log "URL: http://${VPS_IP}:${ASSIGNED_PORT}"
log "Usuario: admin"
log "Contraseña: $BASIC_AUTH_PASSWORD"
log ""
PROVEOF

chmod +x scripts/provision_nossl.sh

log "Scripts creados"

# Mostrar credenciales
echo ""
echo -e "${YELLOW}================================================"
echo "   CREDENCIALES GENERADAS"
echo "================================================${NC}"
echo ""
echo "Panel de Control:"
echo "  URL: http://$VPS_IP:3000"
echo "  Usuario: admin"
echo "  Contraseña: $(grep PANEL_ADMIN_PASSWORD .env | cut -d'=' -f2)"
echo ""
echo -e "${YELLOW}⚠️  GUARDA ESTAS CREDENCIALES EN UN LUGAR SEGURO${NC}"
echo ""
read -p "Presiona Enter para continuar..."

# ================================================
# INICIAR SERVICIOS
# ================================================
echo ""
log "Iniciando servicios base..."

docker-compose -f docker-compose-nossl.yml up -d

log "Esperando a que los servicios estén listos..."
sleep 10

# Verificar PostgreSQL
for i in {1..30}; do
    if docker exec nexo_postgres pg_isready -U nexo_admin &> /dev/null; then
        log "PostgreSQL listo"
        break
    fi
    sleep 2
done

# Crear base de datos del panel
docker exec nexo_postgres psql -U nexo_admin -c "CREATE DATABASE nexo_control;" 2>/dev/null || true

log "Panel de control iniciando..."
sleep 5

# ================================================
# VERIFICAR INSTALACIÓN
# ================================================
echo ""
log "Verificando instalación..."

# Verificar contenedores
RUNNING=$(docker ps --format '{{.Names}}' | wc -l)
log "Contenedores corriendo: $RUNNING"

# Verificar panel
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000" | grep -q "200\|401"; then
    log "Panel de control accesible"
else
    warning "Panel de control no responde todavía (puede tardar 1-2 minutos más)"
fi

# ================================================
# DAR PERMISOS A SCRIPTS
# ================================================
log "Configurando permisos..."
chmod +x scripts/*.sh 2>/dev/null || true

# ================================================
# RESUMEN FINAL
# ================================================
echo ""
echo -e "${GREEN}================================================"
echo "   ✅ INSTALACIÓN COMPLETADA"
echo "================================================${NC}"
echo ""
echo "📊 INFORMACIÓN DEL SISTEMA:"
echo "  - Directorio: $INSTALL_DIR"
echo "  - IP Pública: $VPS_IP"
echo "  - Contenedores: $(docker ps --format '{{.Names}}' | wc -l)"
echo ""
echo "🌐 ACCESOS:"
echo "  - Panel Control: http://$VPS_IP:3000"
echo "  - Usuario: admin"
echo "  - Contraseña: $(grep PANEL_ADMIN_PASSWORD .env | cut -d'=' -f2)"
echo ""
echo "📝 PRÓXIMOS PASOS:"
echo ""
echo "1. Acceder al panel en tu navegador:"
echo "   http://$VPS_IP:3000"
echo ""
echo "2. Crear tu primera instancia:"
echo "   cd $INSTALL_DIR"
echo "   ./scripts/provision_nossl.sh cliente1 premium"
echo ""
echo "3. Ver guía completa:"
echo "   cat INSTALL_HOSTINGER_NOSSL.md"
echo ""
echo "4. Ver todas las instancias:"
echo "   docker ps | grep n8n_"
echo ""
echo "📚 COMANDOS ÚTILES:"
echo "  - Ver logs: docker-compose -f docker-compose-nossl.yml logs -f"
echo "  - Reiniciar: docker-compose -f docker-compose-nossl.yml restart"
echo "  - Detener: docker-compose -f docker-compose-nossl.yml down"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:"
echo "  - Guarda las credenciales en un lugar seguro"
echo "  - Los puertos 3000 y 5678-5698 deben estar abiertos"
echo "  - Cada nueva instancia usará un puerto secuencial${NC}"
echo ""
echo -e "${GREEN}¡Sistema listo para crear instancias de clientes! 🚀${NC}"
echo ""
