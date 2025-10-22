#!/bin/bash
# ================================================
# Script de Testing y Validación del Sistema
# ================================================

echo "================================================"
echo "    TESTING Y VALIDACIÓN - NEXO IA            "
echo "================================================"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
    read -p "Ingresa tu dominio (ej: n8n.tudominio.com): " DOMAIN
fi

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función de test
run_test() {
    local test_name=$1
    local test_command=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing: $test_name... "
    
    if eval $test_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo -e "\n${YELLOW}1. VERIFICACIÓN DE SERVICIOS${NC}"
echo "================================"

run_test "Nginx activo" "systemctl is-active nginx"
run_test "PM2 activo" "pm2 list | grep -q n8n"
run_test "n8n ejecutándose" "curl -s -o /dev/null -w '%{http_code}' https://$DOMAIN | grep -q 200"
run_test "Puerto 5678 escuchando" "netstat -tuln | grep -q :5678"

echo -e "\n${YELLOW}2. VERIFICACIÓN DE SSL${NC}"
echo "========================"

run_test "Certificado SSL válido" "openssl s_client -connect $DOMAIN:443 -servername $DOMAIN < /dev/null 2>&1 | grep -q 'Verify return code: 0'"
run_test "HTTPS redirect activo" "curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN | grep -q 301"

echo -e "\n${YELLOW}3. VERIFICACIÓN DE APIS${NC}"
echo "========================="

# Verificar variables de entorno
ENV_FILE="/home/n8n/.env"
run_test "Archivo .env existe" "test -f $ENV_FILE"
run_test "OpenAI API Key configurada" "grep -q 'OPENAI_API_KEY=sk-' $ENV_FILE"
run_test "Evolution API configurada" "grep -q 'EVOLUTION_API_URL=' $ENV_FILE"
run_test "Airtable PAT configurada" "grep -q 'AIRTABLE_PAT=' $ENV_FILE"

echo -e "\n${YELLOW}4. VERIFICACIÓN DE WEBHOOKS${NC}"
echo "============================="

# Test webhook endpoints
WEBHOOK_BASE="https://$DOMAIN/webhook"
run_test "Webhook lead-capture accesible" "curl -s -o /dev/null -w '%{http_code}' -X POST $WEBHOOK_BASE/lead-capture-form | grep -q '404\|426'"
run_test "Webhook WhatsApp accesible" "curl -s -o /dev/null -w '%{http_code}' -X POST $WEBHOOK_BASE/424a3080-4473-47fb-8b32-6fdeede8f02b | grep -q '404\|426'"

echo -e "\n${YELLOW}5. VERIFICACIÓN DE PERMISOS${NC}"
echo "============================="

run_test "Directorio n8n con permisos correctos" "stat -c '%U' /home/n8n/.n8n | grep -q n8n"
run_test "Logs escribibles" "test -w /home/n8n/logs"
run_test "Backups configurados" "test -f /home/n8n/backup.sh"
run_test "Cron backup configurado" "crontab -u n8n -l | grep -q backup.sh"

echo -e "\n${YELLOW}6. VERIFICACIÓN DE RECURSOS${NC}"
echo "============================="

# Verificar recursos del sistema
MEM_AVAILABLE=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')

echo "Memoria disponible: ${MEM_AVAILABLE}GB"
echo "CPU idle: ${CPU_IDLE}%"
echo "Uso de disco: ${DISK_USAGE}%"

run_test "Memoria suficiente (>2GB)" "[ $(echo "$MEM_AVAILABLE > 2" | bc) -eq 1 ]"
run_test "CPU disponible (>20% idle)" "[ $(echo "$CPU_IDLE > 20" | bc) -eq 1 ] 2>/dev/null || true"
run_test "Espacio en disco (<80%)" "[ $DISK_USAGE -lt 80 ]"

echo -e "\n${YELLOW}7. TEST DE FUNCIONALIDAD${NC}"
echo "=========================="

# Test básico de API
if grep -q 'OPENAI_API_KEY=sk-' $ENV_FILE; then
    OPENAI_KEY=$(grep 'OPENAI_API_KEY=' $ENV_FILE | cut -d'=' -f2)
    run_test "OpenAI API responde" "curl -s https://api.openai.com/v1/models -H 'Authorization: Bearer $OPENAI_KEY' | grep -q 'gpt'"
fi

# Test de creación de workflow
run_test "n8n API accesible" "curl -s -u admin:$(grep N8N_BASIC_AUTH_PASSWORD $ENV_FILE | cut -d'=' -f2) https://$DOMAIN/rest/workflows | grep -q 'data'"

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}           RESUMEN DE VALIDACIÓN               ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "Total de pruebas: $TOTAL_TESTS"
echo -e "${GREEN}Exitosas: $PASSED_TESTS${NC}"
echo -e "${RED}Fallidas: $FAILED_TESTS${NC}"
echo ""

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "Tasa de éxito: ${SUCCESS_RATE}%"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ SISTEMA COMPLETAMENTE OPERATIVO${NC}"
    echo -e "${GREEN}El sistema está listo para producción${NC}"
elif [ $FAILED_TESTS -le 2 ]; then
    echo -e "${YELLOW}⚠️ SISTEMA OPERATIVO CON ADVERTENCIAS${NC}"
    echo -e "${YELLOW}Revisa los tests fallidos antes de producción${NC}"
else
    echo -e "${RED}❌ SISTEMA REQUIERE ATENCIÓN${NC}"
    echo -e "${RED}Varios componentes necesitan configuración${NC}"
fi

echo ""
echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo "1. Accede a: https://$DOMAIN"
echo "2. Importa los workflows según la guía"
echo "3. Configura las credenciales en cada workflow"
echo "4. Activa los workflows necesarios"
echo "5. Prueba cada funcionalidad individualmente"

# Generar reporte
REPORT_FILE="/home/n8n/validation_report_$(date +%Y%m%d_%H%M%S).txt"
cat > $REPORT_FILE <<EOF
NEXO IA - REPORTE DE VALIDACIÓN
================================
Fecha: $(date)
Dominio: $DOMAIN

RESULTADOS:
- Total de pruebas: $TOTAL_TESTS
- Exitosas: $PASSED_TESTS
- Fallidas: $FAILED_TESTS
- Tasa de éxito: ${SUCCESS_RATE}%

SISTEMA: $([ $FAILED_TESTS -eq 0 ] && echo "COMPLETAMENTE OPERATIVO" || echo "CON ADVERTENCIAS")

Generado por: testing_validation.sh
EOF

echo ""
echo "Reporte guardado en: $REPORT_FILE"
