# 🎯 Ejemplo Real de Uso - Sistema Multi-Tenant

## Escenario: Tienes 3 clientes nuevos

### Cliente 1: "Restaurante El Sabor"
- **Pack**: Estándar
- **Necesita**: WhatsApp + Gmail + Formulario de reservas

### Cliente 2: "Clínica Dental Sonrisa"  
- **Pack**: Premium
- **Necesita**: Todo lo anterior + Voice + Email marketing

### Cliente 3: "Grupo Empresarial NEXO"
- **Pack**: NEXA
- **Necesita**: Todo + Personal Assistant + Analytics

## 📝 Proceso Completo de Alta

### 1. Crear instancia para Restaurante
```bash
./scripts/provision_instance.sh restaurante-sabor estandar
```

**Output:**
```
[10:23:15] Aprovisionando: restaurante-sabor - Plan: estandar
[10:23:16] Creando base de datos...
[10:23:18] Iniciando contenedor Docker...
[10:23:25] Importando workflows del plan: estandar...
  ✓ Agente_recepcionista_NEXO
  ✓ Agente_Atencion_Gmail
  ✓ Captacion_Leads_Formulario

================================================
   ✅ INSTANCIA CREADA EXITOSAMENTE
================================================

Cliente: restaurante-sabor
Plan: estandar
URL: https://restaurante-sabor.tudominio.com
Usuario: admin
Contraseña: X7k9mP2n5Q

Workflows importados: 3
```

### 2. Configurar APIs del restaurante
```bash
cd instances/restaurante-sabor
nano .env

# Agregar:
OPENAI_API_KEY=sk-proj-abc123...
EVOLUTION_API_URL=https://api.evolution.com
EVOLUTION_API_KEY=rest123...
GOOGLE_CLIENT_ID=123456.apps.googleusercontent.com

# Reiniciar
./manage.sh restart
```

### 3. Crear instancia para Clínica
```bash
./scripts/provision_instance.sh clinica-sonrisa premium
```

**Output:**
```
URL: https://clinica-sonrisa.tudominio.com
Usuario: admin
Contraseña: B3n7wK4m9L
Workflows importados: 6
```

### 4. Crear instancia para Grupo Empresarial
```bash
# Con APIs pre-configuradas
cat > nexo_config.json <<EOF
{
  "OPENAI_API_KEY": "sk-proj-xyz789...",
  "EVOLUTION_API_URL": "https://api.evolution.com",
  "EVOLUTION_API_KEY": "nexo789...",
  "AIRTABLE_PAT": "pat_nexo123...",
  "TELEGRAM_BOT_TOKEN": "7123456789:AAF..."
}
EOF

./scripts/provision_instance.sh grupo-nexo nexa nexo_config.json
```

**Output:**
```
URL: https://grupo-nexo.tudominio.com
Usuario: admin
Contraseña: M5p8nQ2x7R
Workflows importados: 10
APIs pre-configuradas: ✓
```

## 📊 Ver todas las instancias activas
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Output:**
```
NAMES                  STATUS              PORTS
n8n_restaurante-sabor  Up 5 minutes       5678/tcp
n8n_clinica-sonrisa    Up 3 minutes       5678/tcp
n8n_grupo-nexo         Up 1 minute        5678/tcp
nexo_traefik           Up 1 hour          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
nexo_postgres          Up 1 hour          5432/tcp
nexo_control_panel     Up 1 hour          3000/tcp
```

## 🌐 URLs de Acceso

### Clientes:
- Restaurante: https://restaurante-sabor.tudominio.com
- Clínica: https://clinica-sonrisa.tudominio.com
- Grupo NEXO: https://grupo-nexo.tudominio.com

### Administración:
- Panel Control: https://admin.tudominio.com
- Dashboard Traefik: https://traefik.tudominio.com

## 💰 Facturación Mensual

### Desde el Panel de Control:
```bash
curl https://admin.tudominio.com/api/billing/report/2025-01
```

**Output:**
```json
{
  "month": "2025-01",
  "clients": [
    {
      "client_id": "restaurante-sabor",
      "plan": "estandar",
      "price": 99.00,
      "usage": {
        "workflows_executed": 1523,
        "api_calls": 4821,
        "storage_mb": 125
      }
    },
    {
      "client_id": "clinica-sonrisa",
      "plan": "premium",
      "price": 199.00,
      "usage": {
        "workflows_executed": 3742,
        "api_calls": 8923,
        "storage_mb": 342
      }
    },
    {
      "client_id": "grupo-nexo",
      "plan": "nexa",
      "price": 399.00,
      "usage": {
        "workflows_executed": 8921,
        "api_calls": 23841,
        "storage_mb": 1823
      }
    }
  ],
  "total": 697.00
}
```

## 🔧 Gestión Diaria

### Ver logs de un cliente específico:
```bash
cd instances/restaurante-sabor
./manage.sh logs
```

### Hacer backup manual:
```bash
cd instances/clinica-sonrisa
./manage.sh backup
```

### Reiniciar instancia:
```bash
cd instances/grupo-nexo
./manage.sh restart
```

### Ver uso de recursos:
```bash
docker stats --no-stream | grep n8n_
```

**Output:**
```
n8n_restaurante-sabor   0.23%   312MiB / 2GiB     15.2%
n8n_clinica-sonrisa     0.45%   523MiB / 3GiB     17.0%
n8n_grupo-nexo          0.67%   892MiB / 4GiB     21.8%
```

## 🚨 Si un cliente no paga:

### Suspender instancia:
```bash
docker stop n8n_restaurante-sabor
```

### Reactivar cuando pague:
```bash
docker start n8n_restaurante-sabor
```

### Eliminar definitivamente:
```bash
cd instances
rm -rf restaurante-sabor
docker rm n8n_restaurante-sabor
docker exec nexo_postgres psql -U nexo_admin -c "DROP DATABASE n8n_restaurante_sabor;"
```

## 📈 Escalabilidad

Con un VPS de 32GB RAM puedes tener:
- ~15 clientes Pack NEXA (4GB c/u)
- ~20 clientes Pack Premium (3GB c/u)
- ~30 clientes Pack Estándar (2GB c/u)

O una mezcla de todos.

## 🎯 Resultado Final

**3 clientes configurados en menos de 10 minutos**, cada uno con:
- ✅ Su propia instancia n8n
- ✅ Su propio dominio SSL
- ✅ Sus workflows pre-cargados
- ✅ Sus APIs configuradas
- ✅ Totalmente aislados entre sí
- ✅ Listos para usar inmediatamente

**Todo con comandos simples, sin configuración manual de Docker.**
