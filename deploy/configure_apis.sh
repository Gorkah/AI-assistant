#!/bin/bash
# ================================================
# Script de Configuración de APIs y Credenciales
# ================================================

echo "================================================"
echo "   Configuración de APIs para NEXO IA          "
echo "================================================"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV_FILE="/home/n8n/.env"

# Función para actualizar .env
update_env() {
    key=$1
    value=$2
    if grep -q "^$key=" "$ENV_FILE"; then
        sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
    else
        echo "$key=$value" >> "$ENV_FILE"
    fi
    echo -e "${GREEN}✓ $key configurado${NC}"
}

echo -e "\n${YELLOW}1. CONFIGURACIÓN DE OPENAI${NC}"
echo "Obtén tu API Key desde: https://platform.openai.com/api-keys"
read -p "OpenAI API Key (sk-...): " openai_key
update_env "OPENAI_API_KEY" "$openai_key"

echo -e "\n${YELLOW}2. CONFIGURACIÓN DE EVOLUTION API (WhatsApp)${NC}"
echo "Si usas Evolution API cloud: https://evolution-api.com"
read -p "Evolution API URL: " evolution_url
read -p "Evolution API Key: " evolution_key
read -p "Nombre de instancia WhatsApp: " evolution_instance
update_env "EVOLUTION_API_URL" "$evolution_url"
update_env "EVOLUTION_API_KEY" "$evolution_key"
update_env "EVOLUTION_INSTANCE_NAME" "$evolution_instance"

echo -e "\n${YELLOW}3. CONFIGURACIÓN DE AIRTABLE${NC}"
echo "Crear token en: https://airtable.com/create/tokens"
read -p "Airtable Personal Access Token: " airtable_pat
read -p "Airtable Base ID del CRM: " airtable_base
update_env "AIRTABLE_PAT" "$airtable_pat"
update_env "AIRTABLE_CRM_BASE_ID" "$airtable_base"

echo -e "\n${YELLOW}4. CONFIGURACIÓN DE GOOGLE WORKSPACE${NC}"
echo "Configurar en: https://console.cloud.google.com"
read -p "Google Client ID: " google_client_id
read -p "Google Client Secret: " google_secret
read -p "ID de Google Sheet para Leads: " sheet_leads
read -p "ID de Google Sheet para Facturas: " sheet_facturas
update_env "GOOGLE_CLIENT_ID" "$google_client_id"
update_env "GOOGLE_CLIENT_SECRET" "$google_secret"
update_env "GOOGLE_SHEETS_LEADS_ID" "$sheet_leads"
update_env "GOOGLE_SHEETS_FACTURAS_ID" "$sheet_facturas"

echo -e "\n${YELLOW}5. CONFIGURACIÓN DE TELEGRAM (Opcional)${NC}"
read -p "¿Configurar Telegram Bot? (s/n): " config_telegram
if [[ $config_telegram == "s" ]]; then
    echo "Crear bot con @BotFather en Telegram"
    read -p "Telegram Bot Token: " telegram_token
    read -p "Chat ID del CEO: " telegram_ceo
    update_env "TELEGRAM_BOT_TOKEN" "$telegram_token"
    update_env "TELEGRAM_CEO_CHAT_ID" "$telegram_ceo"
fi

echo -e "\n${YELLOW}6. CONFIGURACIÓN DE CREDENCIALES N8N${NC}"
read -p "Nuevo usuario admin: " n8n_user
read -sp "Nueva contraseña admin: " n8n_pass
echo ""
update_env "N8N_BASIC_AUTH_USER" "$n8n_user"
update_env "N8N_BASIC_AUTH_PASSWORD" "$n8n_pass"

echo -e "\n${GREEN}✅ Configuración completada${NC}"
echo "Reiniciando n8n..."
su - n8n -c 'pm2 restart n8n'
echo -e "${GREEN}✅ n8n reiniciado con nueva configuración${NC}"
