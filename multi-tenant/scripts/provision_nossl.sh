#!/bin/bash
# ================================================
# NEXO IA - Aprovisionamiento SIN SSL (Por IP)
# ================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Verificar argumentos
[ $# -lt 2 ] && error "Uso: $0 <cliente_id> <plan>"

CLIENT_ID=$1
PLAN=$2

[[ ! $CLIENT_ID =~ ^[a-z0-9-]+$ ]] && error "cliente_id inválido (solo minúsculas, números y guiones)"
[[ ! $PLAN =~ ^(estandar|premium|nexa)$ ]] && error "Plan debe ser: estandar|premium|nexa"

# Directorios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTANCES_DIR="$PROJECT_ROOT/instances"

# Cargar variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    error "Archivo .env no encontrado. Copia .env.nossl a .env y configúralo"
fi

source "$PROJECT_ROOT/.env"

# Verificar que no exista
[ -d "$INSTANCES_DIR/$CLIENT_ID" ] && error "Instancia ya existe: $CLIENT_ID"

log "================================================"
log "   Creando instancia: $CLIENT_ID - Plan: $PLAN"
log "================================================"

# Calcular puerto disponible
CURRENT_INSTANCES=$(ls -1 "$INSTANCES_DIR" 2>/dev/null | wc -l)
ASSIGNED_PORT=$((BASE_PORT + CURRENT_INSTANCES))

# Verificar que el puerto no esté en uso
if netstat -tuln 2>/dev/null | grep -q ":$ASSIGNED_PORT "; then
    error "Puerto $ASSIGNED_PORT ya está en uso"
fi

# Crear estructura
CLIENT_DIR="$INSTANCES_DIR/$CLIENT_ID"
mkdir -p "$CLIENT_DIR"/{data,workflows,backups,logs}

# Generar credenciales
DB_NAME="n8n_${CLIENT_ID//-/_}"
DB_USER="n8n_${CLIENT_ID//-/_}"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)

log "Puerto asignado: $ASSIGNED_PORT"
log "Creando base de datos..."

# Crear base de datos
docker exec nexo_postgres psql -U $POSTGRES_ADMIN_USER <<-EOSQL
    CREATE DATABASE $DB_NAME;
    CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL

# Crear .env de la instancia
cat > "$CLIENT_DIR/.env" <<EOF
# Instance: $CLIENT_ID
# Plan: $PLAN
# Port: $ASSIGNED_PORT
# Created: $(date)

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
EXECUTIONS_DATA_MAX_AGE=336

GENERIC_TIMEZONE=${DEFAULT_TIMEZONE}
EOF

# Crear docker-compose de la instancia
cat > "$CLIENT_DIR/docker-compose.yml" <<EOF
version: '3.8'

networks:
  nexo_network:
    external: true

services:
  n8n_${CLIENT_ID}:
    image: n8nio/n8n:${DEFAULT_N8N_VERSION}
    container_name: n8n_${CLIENT_ID}
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./data:/home/node/.n8n
      - ./workflows:/workflows
      - ./backups:/backups
    networks:
      - nexo_network
    ports:
      - "${ASSIGNED_PORT}:5678"
    depends_on:
      - postgres
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2g
EOF

log "Iniciando contenedor..."
cd "$CLIENT_DIR"
docker-compose up -d

# Esperar a que esté listo
log "Esperando a que n8n esté listo..."
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ASSIGNED_PORT}" | grep -q "200\|401"; then
        break
    fi
    sleep 2
done

# Importar workflows según plan
log "Importando workflows del plan: $PLAN..."

WORKFLOWS_SOURCE="$PROJECT_ROOT/../"

case $PLAN in
    estandar)
        WORKFLOWS=(
            "Recepcionista/Agente_recepcionista_NEXO"
            "Gmail/Agente_Atencion_Gmail"
            "Leads/Captacion_Leads_Formulario"
        )
        ;;
    premium)
        WORKFLOWS=(
            "Recepcionista/Agente_recepcionista_NEXO"
            "Gmail/Agente_Atencion_Gmail"
            "Leads/Captacion_Leads_Formulario"
            "Recepcionista/Agente_Voice_WhatsApp"
            "Email/Email_Icebreaker_Personalizado"
            "Facturas/Automatiza_facturas"
        )
        ;;
    nexa)
        WORKFLOWS=(
            "Recepcionista/Agente_recepcionista_NEXO"
            "Gmail/Agente_Atencion_Gmail"
            "Leads/Captacion_Leads_Formulario"
            "Recepcionista/Agente_Voice_WhatsApp"
            "Email/Email_Icebreaker_Personalizado"
            "Facturas/Automatiza_facturas"
            "Telegram/Telegram_asistant"
            "Personal_Assistant/Personal_Assistant_whatsapp"
            "Videos/VEO_3_VIDEOS"
            "Analytics/Agente_Analisis_Empresarial"
        )
        ;;
esac

for workflow in "${WORKFLOWS[@]}"; do
    # Buscar el archivo
    FOUND=$(find "$WORKFLOWS_SOURCE" -name "$(basename $workflow).json" -type f 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        cp "$FOUND" "$CLIENT_DIR/workflows/"
        log "  ✓ $(basename $workflow)"
    else
        log "  ⚠ $(basename $workflow) no encontrado"
    fi
done

# Guardar info de la instancia
cat > "$CLIENT_DIR/instance_info.json" <<EOF
{
  "client_id": "$CLIENT_ID",
  "plan": "$PLAN",
  "port": $ASSIGNED_PORT,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "url": "http://${VPS_IP}:${ASSIGNED_PORT}",
  "container": "n8n_${CLIENT_ID}",
  "status": "active"
}
EOF

# Script de gestión
cat > "$CLIENT_DIR/manage.sh" <<'MANAGE_EOF'
#!/bin/bash
ACTION=$1

case $ACTION in
    start)   docker-compose up -d ;;
    stop)    docker-compose down ;;
    restart) docker-compose restart ;;
    logs)    docker-compose logs -f --tail=100 ;;
    status)  docker-compose ps ;;
    backup)  
        tar -czf "backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz" data/
        echo "Backup creado en backups/"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status|backup}"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x "$CLIENT_DIR/manage.sh"

log ""
log "================================================"
log "   ✅ INSTANCIA CREADA EXITOSAMENTE"
log "================================================"
log ""
log "Cliente: $CLIENT_ID"
log "Plan: $PLAN"
log "URL: http://${VPS_IP}:${ASSIGNED_PORT}"
log "Usuario: admin"
log "Contraseña: $BASIC_AUTH_PASSWORD"
log ""
log "Contenedor: n8n_${CLIENT_ID}"
log "Workflows: ${#WORKFLOWS[@]} importados"
log ""
log "⚠️  IMPORTANTE:"
log "1. Abre el puerto $ASSIGNED_PORT en el firewall de Hostinger"
log "2. El cliente debe configurar sus API Keys en n8n"
log ""
log "Gestión:"
log "  cd $CLIENT_DIR"
log "  ./manage.sh logs"
log ""

exit 0
