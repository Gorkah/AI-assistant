#!/bin/bash
# ================================================
# NEXO IA - Ejemplos de API REST
# ================================================

BASE_URL="https://admin.nexoai.com"
API_KEY="tu_api_key_aqui"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "   NEXO IA - Ejemplos de API REST             "
echo "================================================"
echo ""

# ================================================
# 1. CREAR NUEVA INSTANCIA
# ================================================
echo -e "${YELLOW}1. Crear Nueva Instancia${NC}"
echo "curl -X POST $BASE_URL/api/instances \\"
echo '  -H "Content-Type: application/json" \'
echo '  -H "Authorization: Bearer '$API_KEY'" \'
echo '  -d '\''{'
echo '    "client_id": "empresa_demo",'
echo '    "plan": "premium",'
echo '    "company_name": "Empresa Demo SA",'
echo '    "contact_email": "contacto@empresa.com",'
echo '    "contact_phone": "+34666777888",'
echo '    "apis": {'
echo '      "openai_key": "sk-...",'
echo '      "evolution_url": "https://evolution.com",'
echo '      "evolution_key": "xxxxx",'
echo '      "airtable_pat": "pat..."'
echo '    }'
echo "  }'"
echo ""

# Ejemplo real
# curl -X POST $BASE_URL/api/instances \
#   -H "Content-Type: application/json" \
#   -H "Authorization: Bearer $API_KEY" \
#   -d '{
#     "client_id": "empresa_demo",
#     "plan": "premium",
#     "company_name": "Empresa Demo SA",
#     "contact_email": "contacto@empresa.com"
#   }'

# ================================================
# 2. LISTAR TODAS LAS INSTANCIAS
# ================================================
echo -e "${YELLOW}2. Listar Todas las Instancias${NC}"
echo "curl -X GET $BASE_URL/api/instances \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

# ================================================
# 3. OBTENER DETALLE DE UNA INSTANCIA
# ================================================
echo -e "${YELLOW}3. Obtener Detalle de Instancia${NC}"
echo "curl -X GET $BASE_URL/api/instances/1 \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

# ================================================
# 4. INICIAR/DETENER/REINICIAR INSTANCIA
# ================================================
echo -e "${YELLOW}4. Reiniciar Instancia${NC}"
echo "curl -X POST $BASE_URL/api/instances/1/action/restart \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

echo -e "${YELLOW}5. Detener Instancia${NC}"
echo "curl -X POST $BASE_URL/api/instances/1/action/stop \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

echo -e "${YELLOW}6. Iniciar Instancia${NC}"
echo "curl -X POST $BASE_URL/api/instances/1/action/start \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

# ================================================
# 7. OBTENER ESTADÍSTICAS
# ================================================
echo -e "${YELLOW}7. Obtener Estadísticas de Instancia${NC}"
echo "curl -X GET $BASE_URL/api/instances/1/stats \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

# ================================================
# 8. ACTUALIZAR CONFIGURACIÓN
# ================================================
echo -e "${YELLOW}8. Actualizar Configuración${NC}"
echo "curl -X PATCH $BASE_URL/api/instances/1 \\"
echo '  -H "Content-Type: application/json" \'
echo '  -H "Authorization: Bearer '$API_KEY'" \'
echo '  -d '\''{'
echo '    "company_name": "Nuevo Nombre SA",'
echo '    "contact_email": "nuevo@email.com"'
echo "  }'"
echo ""

# ================================================
# 9. ELIMINAR INSTANCIA (PELIGRO)
# ================================================
echo -e "${YELLOW}9. Eliminar Instancia (CUIDADO)${NC}"
echo "curl -X DELETE $BASE_URL/api/instances/1 \\"
echo '  -H "Authorization: Bearer '$API_KEY'"'
echo ""

# ================================================
# 10. WEBHOOK DE EVENTOS
# ================================================
echo -e "${YELLOW}10. Configurar Webhook de Eventos${NC}"
echo "curl -X POST $BASE_URL/api/webhooks \\"
echo '  -H "Content-Type: application/json" \'
echo '  -H "Authorization: Bearer '$API_KEY'" \'
echo '  -d '\''{'
echo '    "url": "https://tu-sistema.com/webhook",'
echo '    "events": ["instance.created", "instance.stopped", "instance.deleted"]'
echo "  }'"
echo ""

# ================================================
# EJEMPLOS EN PYTHON
# ================================================
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  EJEMPLOS EN PYTHON${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

cat << 'PYTHON_EOF'
import requests

BASE_URL = "https://admin.nexoai.com"
API_KEY = "tu_api_key"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Crear instancia
def create_instance(client_id, plan, company_name, email, apis={}):
    data = {
        "client_id": client_id,
        "plan": plan,
        "company_name": company_name,
        "contact_email": email,
        "apis": apis
    }
    
    response = requests.post(
        f"{BASE_URL}/api/instances",
        json=data,
        headers=headers
    )
    
    return response.json()

# Listar instancias
def list_instances():
    response = requests.get(
        f"{BASE_URL}/api/instances",
        headers=headers
    )
    return response.json()

# Reiniciar instancia
def restart_instance(instance_id):
    response = requests.post(
        f"{BASE_URL}/api/instances/{instance_id}/action/restart",
        headers=headers
    )
    return response.json()

# Uso
if __name__ == "__main__":
    # Crear nueva instancia
    result = create_instance(
        client_id="empresa_python",
        plan="premium",
        company_name="Empresa Python SA",
        email="contact@empresa.com",
        apis={
            "openai_key": "sk-...",
            "airtable_pat": "pat..."
        }
    )
    print("Instancia creada:", result)
    
    # Listar todas
    instances = list_instances()
    print(f"Total instancias: {len(instances)}")
    
    # Reiniciar
    restart_instance(1)
    print("Instancia reiniciada")
PYTHON_EOF

echo ""
echo -e "${GREEN}================================================${NC}"
echo "Para más ejemplos, visita la documentación"
echo "https://admin.nexoai.com/docs"
echo ""
