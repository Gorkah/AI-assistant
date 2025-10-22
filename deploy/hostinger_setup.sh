#!/bin/bash
# ================================================
# NEXO Soluciones IA - Script de Instalación para Hostinger VPS
# ================================================

echo "================================================"
echo "   NEXO IA - Instalación en Hostinger VPS      "
echo "================================================"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
DOMAIN=""
EMAIL=""
N8N_PORT=5678
NODE_VERSION="18"

# Función para verificar éxito
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 completado${NC}"
    else
        echo -e "${RED}✗ Error en $1${NC}"
        exit 1
    fi
}

# 1. ACTUALIZAR SISTEMA
echo -e "\n${YELLOW}1. Actualizando sistema...${NC}"
apt update && apt upgrade -y
check_success "Actualización del sistema"

# 2. INSTALAR DEPENDENCIAS BÁSICAS
echo -e "\n${YELLOW}2. Instalando dependencias básicas...${NC}"
apt install -y curl wget git build-essential software-properties-common ufw nginx certbot python3-certbot-nginx
check_success "Instalación de dependencias"

# 3. INSTALAR NODE.JS
echo -e "\n${YELLOW}3. Instalando Node.js v${NODE_VERSION}...${NC}"
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt install -y nodejs
check_success "Instalación de Node.js"

# Verificar versiones
node_version=$(node --version)
npm_version=$(npm --version)
echo -e "${GREEN}Node.js: $node_version${NC}"
echo -e "${GREEN}NPM: $npm_version${NC}"

# 4. INSTALAR PM2
echo -e "\n${YELLOW}4. Instalando PM2 (Process Manager)...${NC}"
npm install -g pm2
check_success "Instalación de PM2"

# 5. INSTALAR N8N
echo -e "\n${YELLOW}5. Instalando n8n...${NC}"
npm install -g n8n
check_success "Instalación de n8n"

# 6. CREAR USUARIO PARA N8N
echo -e "\n${YELLOW}6. Creando usuario n8n...${NC}"
useradd -m -s /bin/bash n8n
check_success "Creación de usuario n8n"

# 7. CREAR DIRECTORIO DE TRABAJO
echo -e "\n${YELLOW}7. Configurando directorios...${NC}"
mkdir -p /home/n8n/.n8n
mkdir -p /home/n8n/workflows
mkdir -p /home/n8n/backups
mkdir -p /home/n8n/logs
chown -R n8n:n8n /home/n8n
check_success "Configuración de directorios"

# 8. CONFIGURAR FIREWALL
echo -e "\n${YELLOW}8. Configurando firewall...${NC}"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow ${N8N_PORT}/tcp
echo "y" | ufw enable
check_success "Configuración de firewall"

# 9. SOLICITAR INFORMACIÓN
echo -e "\n${YELLOW}9. Configuración del dominio...${NC}"
read -p "Ingresa tu dominio (ej: n8n.tudominio.com): " DOMAIN
read -p "Ingresa tu email para SSL: " EMAIL

# 10. CREAR ARCHIVO DE CONFIGURACIÓN N8N
echo -e "\n${YELLOW}10. Creando configuración de n8n...${NC}"
cat > /home/n8n/.n8n/config.json <<EOL
{
  "host": "0.0.0.0",
  "port": ${N8N_PORT},
  "protocol": "https",
  "webhook_url": "https://${DOMAIN}/",
  "executions": {
    "saveDataOnError": "all",
    "saveDataOnSuccess": "all",
    "saveDataManualExecutions": true,
    "pruneData": true,
    "pruneDataMaxAge": 336
  }
}
EOL
check_success "Creación de archivo de configuración"

# 11. CREAR ARCHIVO .ENV
echo -e "\n${YELLOW}11. Creando archivo .env...${NC}"
cat > /home/n8n/.env <<EOL
# N8N Configuration
N8N_HOST=0.0.0.0
N8N_PORT=${N8N_PORT}
N8N_PROTOCOL=https
WEBHOOK_URL=https://${DOMAIN}/
N8N_PATH=/
N8N_EDITOR_BASE_URL=https://${DOMAIN}/
VUE_APP_URL_BASE_API=https://${DOMAIN}/

# Basic Auth (CAMBIAR ESTOS VALORES)
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=ChangeMeNow123!

# Database (SQLite por defecto)
DB_TYPE=sqlite

# Executions
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_ON_PROGRESS=true
EXECUTIONS_DATA_MAX_AGE=336

# Timezone
GENERIC_TIMEZONE=Europe/Madrid

# Email Config
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER=your-email@gmail.com

# External API Keys (AGREGAR TUS CLAVES AQUÍ)
# OPENAI_API_KEY=
# EVOLUTION_API_URL=
# EVOLUTION_API_KEY=
# AIRTABLE_PAT=
# TELEGRAM_BOT_TOKEN=
EOL
chown n8n:n8n /home/n8n/.env
check_success "Creación de archivo .env"

# 12. CONFIGURAR NGINX
echo -e "\n${YELLOW}12. Configurando Nginx...${NC}"
cat > /etc/nginx/sites-available/n8n <<EOL
server {
    listen 80;
    server_name ${DOMAIN};
    
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://localhost:${N8N_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_connect_timeout 3600s;
        proxy_send_timeout 3600s;
    }
    
    location /webhook/ {
        proxy_pass http://localhost:${N8N_PORT}/webhook/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
check_success "Configuración de Nginx"

# 13. CONFIGURAR SSL CON CERTBOT
echo -e "\n${YELLOW}13. Configurando SSL...${NC}"
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}
check_success "Configuración SSL"

# 14. CREAR SCRIPT DE INICIO PM2
echo -e "\n${YELLOW}14. Creando script de inicio...${NC}"
cat > /home/n8n/start-n8n.sh <<'EOL'
#!/bin/bash
source /home/n8n/.env
export $(cat /home/n8n/.env | xargs)
n8n start
EOL
chmod +x /home/n8n/start-n8n.sh
chown n8n:n8n /home/n8n/start-n8n.sh
check_success "Script de inicio creado"

# 15. CONFIGURAR PM2 ECOSYSTEM
echo -e "\n${YELLOW}15. Configurando PM2...${NC}"
cat > /home/n8n/ecosystem.config.js <<EOL
module.exports = {
  apps: [{
    name: 'n8n',
    script: 'n8n',
    args: 'start',
    cwd: '/home/n8n',
    env: {
      NODE_ENV: 'production'
    },
    env_file: '/home/n8n/.env',
    error_file: '/home/n8n/logs/n8n-error.log',
    out_file: '/home/n8n/logs/n8n-out.log',
    log_file: '/home/n8n/logs/n8n-combined.log',
    time: true,
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',
    watch: false
  }]
};
EOL
chown n8n:n8n /home/n8n/ecosystem.config.js
check_success "PM2 ecosystem configurado"

# 16. CREAR SCRIPT DE BACKUP
echo -e "\n${YELLOW}16. Creando script de backup...${NC}"
cat > /home/n8n/backup.sh <<'EOL'
#!/bin/bash
BACKUP_DIR="/home/n8n/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"

# Crear backup
tar -czf $BACKUP_FILE /home/n8n/.n8n/

# Mantener solo los últimos 30 backups
ls -t $BACKUP_DIR/n8n_backup_*.tar.gz | tail -n +31 | xargs rm -f 2>/dev/null

echo "Backup creado: $BACKUP_FILE"
EOL
chmod +x /home/n8n/backup.sh
chown n8n:n8n /home/n8n/backup.sh
check_success "Script de backup creado"

# 17. CONFIGURAR CRON PARA BACKUPS
echo -e "\n${YELLOW}17. Configurando cron para backups...${NC}"
(crontab -u n8n -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup.sh") | crontab -u n8n -
check_success "Cron configurado"

# 18. INICIAR N8N CON PM2
echo -e "\n${YELLOW}18. Iniciando n8n con PM2...${NC}"
su - n8n -c "pm2 start /home/n8n/ecosystem.config.js"
su - n8n -c "pm2 save"
pm2 startup systemd -u n8n --hp /home/n8n
check_success "n8n iniciado con PM2"

# 19. MOSTRAR INFORMACIÓN FINAL
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}    ✅ INSTALACIÓN COMPLETADA CON ÉXITO       ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}INFORMACIÓN IMPORTANTE:${NC}"
echo -e "URL de acceso: ${GREEN}https://${DOMAIN}${NC}"
echo -e "Usuario: ${GREEN}admin${NC}"
echo -e "Contraseña: ${GREEN}ChangeMeNow123!${NC}"
echo ""
echo -e "${RED}⚠️  IMPORTANTE - CAMBIAR INMEDIATAMENTE:${NC}"
echo -e "1. Editar /home/n8n/.env y cambiar:"
echo -e "   - N8N_BASIC_AUTH_USER"
echo -e "   - N8N_BASIC_AUTH_PASSWORD"
echo -e "   - Agregar las API Keys necesarias"
echo ""
echo -e "2. Reiniciar n8n después de cambios:"
echo -e "   ${YELLOW}su - n8n -c 'pm2 restart n8n'${NC}"
echo ""
echo -e "${GREEN}COMANDOS ÚTILES:${NC}"
echo -e "Ver logs: ${YELLOW}su - n8n -c 'pm2 logs n8n'${NC}"
echo -e "Estado: ${YELLOW}su - n8n -c 'pm2 status'${NC}"
echo -e "Detener: ${YELLOW}su - n8n -c 'pm2 stop n8n'${NC}"
echo -e "Reiniciar: ${YELLOW}su - n8n -c 'pm2 restart n8n'${NC}"
echo ""
echo -e "${GREEN}================================================${NC}"
