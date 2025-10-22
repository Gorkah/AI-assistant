#!/bin/bash
# ================================================
# Script para configurar credenciales en n8n via API
# ================================================

set -e

CLIENT_ID=$1
APIS_JSON=$2

if [ $# -lt 2 ]; then
    echo "Uso: $0 <client_id> <apis_json_file>"
    exit 1
fi

source "../.env"

N8N_URL="https://${CLIENT_ID}.${BASE_DOMAIN}"
INSTANCE_DIR="../instances/${CLIENT_ID}"

# Leer credenciales del archivo .env de la instancia
N8N_USER=$(grep N8N_BASIC_AUTH_USER "$INSTANCE_DIR/.env" | cut -d'=' -f2)
N8N_PASS=$(grep N8N_BASIC_AUTH_PASSWORD "$INSTANCE_DIR/.env" | cut -d'=' -f2)

echo "Configurando credenciales en n8n para: $CLIENT_ID"

# Esperar a que n8n esté listo
echo "Esperando a que n8n esté disponible..."
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|401"; then
        break
    fi
    sleep 2
done

# Función para crear credencial via API
create_credential() {
    local name=$1
    local type=$2
    local data=$3
    
    echo "Creando credencial: $name"
    
    curl -s -X POST "$N8N_URL/rest/credentials" \
        -u "$N8N_USER:$N8N_PASS" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"type\": \"$type\",
            \"data\": $data
        }"
}

# Leer JSON de APIs
if [ ! -f "$APIS_JSON" ]; then
    echo "Error: Archivo $APIS_JSON no encontrado"
    exit 1
fi

# Extraer valores del JSON
OPENAI_KEY=$(jq -r '.OPENAI_API_KEY // empty' "$APIS_JSON")
EVOLUTION_URL=$(jq -r '.EVOLUTION_API_URL // empty' "$APIS_JSON")
EVOLUTION_KEY=$(jq -r '.EVOLUTION_API_KEY // empty' "$APIS_JSON")
AIRTABLE_PAT=$(jq -r '.AIRTABLE_PAT // empty' "$APIS_JSON")
GOOGLE_CLIENT_ID=$(jq -r '.GOOGLE_CLIENT_ID // empty' "$APIS_JSON")
GOOGLE_CLIENT_SECRET=$(jq -r '.GOOGLE_CLIENT_SECRET // empty' "$APIS_JSON")
TELEGRAM_TOKEN=$(jq -r '.TELEGRAM_BOT_TOKEN // empty' "$APIS_JSON")

# Crear credenciales en n8n

# OpenAI
if [ -n "$OPENAI_KEY" ]; then
    create_credential "OpenAI API" "openAiApi" "{\"apiKey\": \"$OPENAI_KEY\"}"
fi

# Evolution API (HTTP Header Auth)
if [ -n "$EVOLUTION_KEY" ]; then
    create_credential "Evolution API" "httpHeaderAuth" "{
        \"name\": \"apikey\",
        \"value\": \"$EVOLUTION_KEY\"
    }"
fi

# Airtable
if [ -n "$AIRTABLE_PAT" ]; then
    create_credential "Airtable" "airtableTokenApi" "{\"accessToken\": \"$AIRTABLE_PAT\"}"
fi

# Google OAuth (requiere flujo OAuth complejo)
if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
    echo "⚠️  Google OAuth requiere flujo de autorización manual"
    echo "El cliente debe configurar esto desde n8n:"
    echo "1. Settings → Credentials → Create New"
    echo "2. Type: Google OAuth2"
    echo "3. Client ID: $GOOGLE_CLIENT_ID"
    echo "4. Click 'Connect' y autorizar"
fi

# Telegram
if [ -n "$TELEGRAM_TOKEN" ]; then
    create_credential "Telegram Bot" "telegramApi" "{\"accessToken\": \"$TELEGRAM_TOKEN\"}"
fi

echo ""
echo "✅ Credenciales configuradas"
echo ""
echo "⚠️  IMPORTANTE:"
echo "El cliente debe abrir cada workflow en n8n y:"
echo "1. Doble click en cada nodo con ⚠️"
echo "2. Seleccionar la credencial creada"
echo "3. Guardar el workflow"
echo ""
