# 🏢 NEXO IA - Sistema Multi-Tenant para n8n

Sistema completo de despliegue automático de instancias n8n aisladas para múltiples clientes.

## 🎯 Características

- ✅ **Aislamiento completo** por cliente (Docker containers)
- ✅ **Base de datos PostgreSQL** separada por instancia  
- ✅ **SSL automático** con Let's Encrypt (Traefik)
- ✅ **Proxy reverso** automático con dominios dinámicos
- ✅ **Panel de control web** para gestión
- ✅ **API REST** para automatización
- ✅ **Workflows pre-configurados** según plan
- ✅ **Scripts de backup** automáticos
- ✅ **Monitoreo** de recursos por instancia

## 📋 Requisitos

### VPS/Servidor:
- **OS:** Ubuntu 22.04 LTS o similar
- **CPU:** 4+ cores (recomendado 8)
- **RAM:** 16 GB mínimo (32 GB recomendado)
- **Disco:** 100 GB SSD mínimo
- **Puertos:** 80, 443 abiertos

### Software:
- Docker 24+
- Docker Compose 2.20+
- Dominio con DNS wildcard configurado

## 🚀 Instalación Rápida

### 1. Clonar repositorio
```bash
git clone https://github.com/tu-usuario/AI-assistant.git
cd AI-assistant/multi-tenant
```

### 2. Configurar variables
```bash
cp .env.example .env
nano .env
```

**Configuración mínima requerida:**
```bash
BASE_DOMAIN=nexoai.com
ACME_EMAIL=admin@nexoai.com
POSTGRES_ADMIN_PASSWORD=TuPasswordSegura123!
REDIS_PASSWORD=RedisPassword123!
PANEL_ADMIN_PASSWORD=AdminPanelPassword123!
```

### 3. Configurar DNS
Crear registro DNS wildcard:
```
*.nexoai.com  A  TU_IP_SERVIDOR
```

### 4. Ejecutar instalación
```bash
chmod +x setup.sh
./setup.sh
```

## 🎛️ Panel de Control

Accede al panel web:
```
https://admin.nexoai.com
```

### Funcionalidades del Panel:
- 📊 Dashboard con estadísticas
- ➕ Crear nuevas instancias
- 🔧 Gestionar instancias existentes
- 📈 Ver uso de recursos
- 🛑 Iniciar/Detener/Reiniciar instancias
- 📦 Backups manuales

## 🔧 Crear Instancias

### Método 1: Script de línea de comandos
```bash
./scripts/provision_instance.sh <cliente_id> <plan>
```

**Ejemplos:**
```bash
# Pack Estándar
./scripts/provision_instance.sh empresa1 estandar

# Pack Premium
./scripts/provision_instance.sh empresa2 premium

# Pack NEXA
./scripts/provision_instance.sh empresa3 nexa
```

### Método 2: API REST
```bash
curl -X POST https://admin.nexoai.com/api/instances \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TU_API_KEY" \
  -d '{
    "client_id": "empresa1",
    "plan": "premium",
    "company_name": "Empresa SA",
    "contact_email": "contacto@empresa.com",
    "apis": {
      "openai_key": "sk-...",
      "evolution_url": "https://...",
      "airtable_pat": "pat..."
    }
  }'
```

### Método 3: Panel Web
1. Acceder a https://admin.nexoai.com
2. Click en "Nueva Instancia"
3. Completar formulario
4. Click en "Crear Instancia"

## 📦 Planes Disponibles

### 🟢 Pack Estándar
**Workflows incluidos:**
- Agente de Atención Cliente (WhatsApp + Gmail)
- Captación de Leads con Formulario Inteligente

**Recursos:**
- 1 CPU
- 2 GB RAM
- 10 GB Storage

### 🟡 Pack Premium
**Todo el Estándar +**
- Agente Voice (WhatsApp con voz)
- Email Icebreaker automatizado
- Organización de Facturas

**Recursos:**
- 1.5 CPU
- 3 GB RAM
- 20 GB Storage

### 🔵 Pack NEXA
**Todo el Premium +**
- Personal Assistant CEO (Telegram/WhatsApp)
- Generación de Videos VEO 3
- Análisis Empresarial con IA

**Recursos:**
- 2 CPU
- 4 GB RAM
- 50 GB Storage

## 🔑 Gestión de Instancias

### Ver estado de todas las instancias:
```bash
docker ps | grep n8n_
```

### Gestionar una instancia específica:
```bash
cd instances/empresa1
./manage.sh status   # Ver estado
./manage.sh logs     # Ver logs
./manage.sh restart  # Reiniciar
./manage.sh backup   # Crear backup
```

### Ver logs en tiempo real:
```bash
docker logs -f n8n_empresa1
```

### Acceder a la base de datos:
```bash
docker exec -it nexo_postgres psql -U nexo_admin -d n8n_empresa1
```

## 🔐 Configuración de APIs del Cliente

Cada cliente debe configurar sus propias API keys. Opciones:

### Opción 1: Editar .env directamente
```bash
cd instances/empresa1
nano .env
```

### Opción 2: Via panel web
1. Acceder a instancia en el panel
2. Sección "Configuración de APIs"
3. Agregar keys necesarias

### Opción 3: Script automatizado
```bash
./scripts/configure_client_apis.sh empresa1 \
  --openai "sk-..." \
  --evolution-url "https://..." \
  --evolution-key "xxx" \
  --airtable "pat..."
```

## 📊 Monitoreo y Estadísticas

### Dashboard de Traefik:
```
https://traefik.nexoai.com
```

### Estadísticas de una instancia:
```bash
docker stats n8n_empresa1
```

### API de estadísticas:
```bash
curl https://admin.nexoai.com/api/instances/1/stats
```

## 🔄 Backups

### Backups automáticos:
- Configurados via cron
- Cada 24 horas
- Retención: 30 días

### Backup manual:
```bash
cd instances/empresa1
./manage.sh backup
```

### Restaurar backup:
```bash
cd instances/empresa1
tar -xzf backups/backup_20250101_120000.tar.gz
./manage.sh restart
```

## 🛡️ Seguridad

### Recomendaciones:
1. **Firewall configurado** (solo 80, 443, 22)
2. **Fail2ban** para protección SSH
3. **Actualizaciones automáticas** del sistema
4. **Backups offsite** (S3, Dropbox, etc.)
5. **Monitoreo 24/7** (UptimeRobot, etc.)

### Configurar firewall:
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

## 🔧 Troubleshooting

### Instancia no arranca:
```bash
cd instances/empresa1
docker-compose logs
```

### SSL no funciona:
```bash
# Verificar logs de Traefik
docker logs nexo_traefik

# Forzar renovación
docker exec nexo_traefik traefik refresh
```

### Base de datos no conecta:
```bash
# Verificar PostgreSQL
docker exec nexo_postgres pg_isready

# Ver logs
docker logs nexo_postgres
```

### Webhooks no funcionan:
1. Verificar DNS propagado: `nslookup empresa1.nexoai.com`
2. Verificar certificado SSL: `curl -I https://empresa1.nexoai.com`
3. Revisar logs de la instancia

## 📈 Escalabilidad

### Límites del sistema:
- **Max instancias:** 50 (configurable en .env)
- **Por instancia:** Hasta 100 workflows activos
- **Ejecuciones:** 10,000 por día por instancia

### Aumentar capacidad:
1. Aumentar recursos del VPS
2. Ajustar límites en `.env`
3. Considerar clúster multi-servidor (avanzado)

## 💰 Costos Estimados

### VPS (Hetzner, DigitalOcean, etc.):
- **Pequeño** (5-10 clientes): $40-60/mes
- **Mediano** (10-20 clientes): $80-120/mes
- **Grande** (20-50 clientes): $160-250/mes

### APIs externas por cliente:
- OpenAI: $20-50/mes
- Evolution API: $15/mes
- Total por cliente: ~$35-65/mes

## 📞 Comandos Útiles

```bash
# Ver todas las instancias
docker ps -a | grep n8n_

# Estado del sistema
docker-compose ps

# Logs del panel de control
docker logs -f nexo_control_panel

# Detener todo
docker-compose down

# Reiniciar servicios base
docker-compose restart traefik postgres redis

# Limpiar contenedores huérfanos
docker system prune -a

# Backup completo del sistema
tar -czf backup_completo.tar.gz instances/ .env

# Ver uso de disco
du -sh instances/*
```

## 🆘 Soporte

- 📧 Email: soporte@nexoai.com
- 📚 Documentación: `/docs`
- 🐛 Issues: GitHub Issues

## 📄 Licencia

Propietario - NEXO Soluciones IA © 2025

---

**¡Sistema Multi-Tenant listo para producción! 🚀**
