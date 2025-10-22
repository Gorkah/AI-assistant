#!/bin/bash
# ================================================
# NEXO IA - Script de Aprovisionamiento Automático
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTANCES_DIR="$PROJECT_ROOT/instances"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Verificar argumentos
[ $# -lt 2 ] && error "Uso: $0 <cliente_id> <plan> [config_json]"

CLIENT_ID=$1
PLAN=$2
CONFIG_JSON=${3:-"{}"}

[[ ! $CLIENT_ID =~ ^[a-z0-9-]+$ ]] && error "cliente_id inválido"
[[ ! $PLAN =~ ^(estandar|premium|nexa)$ ]] && error "Plan debe ser: estandar|premium|nexa"

log "Aprovisionando: $CLIENT_ID - Plan: $PLAN"

# Cargar env
source "$PROJECT_ROOT/.env"

# Verificar que no exista
[ -d "$INSTANCES_DIR/$CLIENT_ID" ] && error "Instancia ya existe"

# Crear directorios
CLIENT_DIR="$INSTANCES_DIR/$CLIENT_ID"
mkdir -p "$CLIENT_DIR"/{data,workflows,backups,logs}

# Generar credenciales
DB_NAME="n8n_${CLIENT_ID//-/_}"
DB_USER="n8n_${CLIENT_ID//-/_}"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)
WEBHOOK_URL="https://${CLIENT_ID}.${BASE_DOMAIN}"

log "Creando base de datos..."
docker exec nexo_postgres psql -U $POSTGRES_ADMIN_USER <<-EOSQL
    CREATE DATABASE $DB_NAME;
    CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL

# Crear archivo .env de la instancia
cat > "$CLIENT_DIR/.env" <<EOF
# Instance: $CLIENT_ID
# Plan: $PLAN
# Created: $(date)

N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=$WEBHOOK_URL
WEBHOOK_URL=$WEBHOOK_URL

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

# APIs (cliente debe configurar)
OPENAI_API_KEY=
EVOLUTION_API_URL=
EVOLUTION_API_KEY=
AIRTABLE_PAT=
TELEGRAM_BOT_TOKEN=
EOF

# Parsear config JSON si existe
if [ "$CONFIG_JSON" != "{}" ]; then
    log "Aplicando configuración personalizada..."
    echo "$CONFIG_JSON" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' >> "$CLIENT_DIR/.env"
fi

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
    depends_on:
      - postgres
    deploy:
      resources:
        limits:
          cpus: '${DEFAULT_CPU_LIMIT}'
          memory: ${DEFAULT_MEMORY_LIMIT}
        reservations:
          memory: ${DEFAULT_MEMORY_RESERVATION}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n-${CLIENT_ID}.rule=Host(\`${CLIENT_ID}.${BASE_DOMAIN}\`)"
      - "traefik.http.routers.n8n-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.n8n-${CLIENT_ID}.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n-${CLIENT_ID}.loadbalancer.server.port=5678"
      - "traefik.docker.network=nexo_network"
EOF

# Iniciar contenedor
log "Iniciando contenedor Docker..."
cd "$CLIENT_DIR"
docker-compose up -d

# Esperar a que esté listo
log "Esperando a que n8n esté listo..."
for i in {1..30}; do
    if docker exec n8n_${CLIENT_ID} wget -q --spider http://localhost:5678 2>/dev/null; then
        break
    fi
    sleep 2
done

# Importar workflows según el plan
log "Importando workflows del plan: $PLAN..."

case $PLAN in
    estandar)
        WORKFLOWS=(
            "Agente_recepcionista_NEXO"
            "Agente_Atencion_Gmail"
            "Captacion_Leads_Formulario"
        )
        ;;
    premium)
        WORKFLOWS=(
            "Agente_recepcionista_NEXO"
            "Agente_Atencion_Gmail"
            "Captacion_Leads_Formulario"
            "Agente_Voice_WhatsApp"
            "Email_Icebreaker_Personalizado"
            "Automatiza_facturas"
        )
        ;;
    nexa)
        WORKFLOWS=(
            "Agente_recepcionista_NEXO"
            "Agente_Atencion_Gmail"
            "Captacion_Leads_Formulario"
            "Agente_Voice_WhatsApp"
            "Email_Icebreaker_Personalizado"
            "Automatiza_facturas"
            "Telegram_asistant"
            "Personal_Assistant_whatsapp"
            "VEO_3_VIDEOS"
            "Agente_Analisis_Empresarial"
        )
        ;;
esac

WORKFLOWS_SOURCE="$PROJECT_ROOT/../"
for workflow in "${WORKFLOWS[@]}"; do
    if [ -f "$WORKFLOWS_SOURCE/workflows/${workflow}.json" ]; then
        cp "$WORKFLOWS_SOURCE/workflows/${workflow}.json" "$CLIENT_DIR/workflows/"
        log "  ✓ $workflow"
    else
        warning "  ✗ $workflow no encontrado"
    fi
done

# Guardar información de la instancia
cat > "$CLIENT_DIR/instance_info.json" <<EOF
{
  "client_id": "$CLIENT_ID",
  "plan": "$PLAN",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "url": "$WEBHOOK_URL",
  "database": "$DB_NAME",
  "container": "n8n_${CLIENT_ID}",
  "status": "active",
  "credentials": {
    "admin_user": "admin",
    "admin_password": "$BASIC_AUTH_PASSWORD"
  }
}
EOF

# Registrar en base de datos de control
docker exec nexo_postgres psql -U $POSTGRES_ADMIN_USER -d nexo_control <<-EOSQL
    INSERT INTO instances (client_id, plan, url, status, created_at)
    VALUES ('$CLIENT_ID', '$PLAN', '$WEBHOOK_URL', 'active', NOW());
EOSQL

log ""
log "================================================"
log "   ✅ INSTANCIA CREADA EXITOSAMENTE"
log "================================================"
log ""
log "Cliente: $CLIENT_ID"
log "Plan: $PLAN"
log "URL: $WEBHOOK_URL"
log "Usuario: admin"
log "Contraseña: $BASIC_AUTH_PASSWORD"
log ""
log "Directorio: $CLIENT_DIR"
log "Contenedor: n8n_${CLIENT_ID}"
log ""
log "Workflows importados: ${#WORKFLOWS[@]}"
log ""
log "IMPORTANTE: El cliente debe configurar sus API Keys"
log "Editar: $CLIENT_DIR/.env"
log ""

# Crear script de gestión
cat > "$CLIENT_DIR/manage.sh" <<'MANAGE_EOF'
#!/bin/bash
ACTION=$1
CONTAINER=$(basename $(dirname $(readlink -f $0)) | sed 's/^/n8n_/')

case $ACTION in
    start)   docker-compose up -d ;;
    stop)    docker-compose down ;;
    restart) docker-compose restart ;;
    logs)    docker-compose logs -f --tail=100 ;;
    status)  docker-compose ps ;;
    backup)  
        tar -czf "backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz" data/
        echo "Backup created in backups/"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status|backup}"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x "$CLIENT_DIR/manage.sh"

log "Script de gestión creado: $CLIENT_DIR/manage.sh"
log ""

exit 0
