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
# DESCARGAR REPOSITORIO
# ================================================
echo ""
log "Configurando repositorio..."

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

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Si tienes el repo en GitHub
    # git clone https://github.com/tu-usuario/AI-assistant.git .
    
    # Por ahora, copiar archivos locales si existen
    if [ -d "/root/AI-assistant/multi-tenant" ]; then
        log "Copiando archivos desde instalación local..."
        cp -r /root/AI-assistant/multi-tenant/* "$INSTALL_DIR/"
    else
        warning "No se encontró repositorio local"
        warning "Crea los archivos manualmente en: $INSTALL_DIR"
    fi
fi

cd "$INSTALL_DIR"

# ================================================
# CREAR DIRECTORIOS
# ================================================
log "Creando estructura de directorios..."
mkdir -p instances scripts control-panel/templates

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

if [ ! -f "docker-compose-nossl.yml" ]; then
    error "Archivo docker-compose-nossl.yml no encontrado"
fi

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
