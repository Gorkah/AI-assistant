# 🚀 Guía Rápida - Sistema Multi-Tenant NEXO IA

## ⚡ Despliegue en 5 Minutos

### 1️⃣ **Requisitos Previos**
- VPS con Ubuntu 22.04 (mínimo 16GB RAM, 4 CPU)
- Dominio con wildcard DNS configurado
- Docker y Docker Compose instalados

### 2️⃣ **Instalación**
```bash
# Clonar repo
git clone https://github.com/tu-usuario/AI-assistant.git
cd AI-assistant/multi-tenant

# Configurar
cp .env.example .env
nano .env  # Editar BASE_DOMAIN y ACME_EMAIL

# Instalar
chmod +x setup.sh
./setup.sh
```

### 3️⃣ **Configurar DNS**
Crear registro DNS wildcard:
```
*.tudominio.com  →  IP_DE_TU_VPS
```

### 4️⃣ **Crear Primera Instancia**
```bash
./scripts/provision_instance.sh cliente1 premium
```

### 5️⃣ **¡Listo!**
Accede a:
- Panel: `https://admin.tudominio.com`
- Instancia: `https://cliente1.tudominio.com`

---

## 📊 Uso Diario

### Crear Nueva Instancia para Cliente

**Opción A: Script** (Más rápido)
```bash
./scripts/provision_instance.sh nombre_cliente premium
```

**Opción B: Panel Web**
1. Ir a `https://admin.tudominio.com`
2. Click "Nueva Instancia"
3. Llenar formulario
4. Click "Crear"

**Opción C: API**
```bash
curl -X POST https://admin.tudominio.com/api/instances \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "cliente2",
    "plan": "premium",
    "company_name": "Empresa SA",
    "contact_email": "contacto@empresa.com"
  }'
```

### Gestionar Instancia Existente

```bash
# Entrar a directorio de instancia
cd instances/cliente1

# Ver estado
./manage.sh status

# Ver logs
./manage.sh logs

# Reiniciar
./manage.sh restart

# Backup
./manage.sh backup
```

### Configurar APIs del Cliente

**Método 1: Editar .env**
```bash
cd instances/cliente1
nano .env
# Agregar: OPENAI_API_KEY=sk-...
./manage.sh restart
```

**Método 2: Script**
```bash
./scripts/configure_apis.sh cliente1 \
  --openai "sk-..." \
  --evolution-url "https://..." \
  --airtable "pat..."
```

---

## 🎯 Planes y Workflows

### 🟢 Pack Estándar ($99/mes)
```bash
./scripts/provision_instance.sh cliente estandar
```
**Incluye:**
- Agente WhatsApp
- Agente Gmail
- Captación de Leads

### 🟡 Pack Premium ($199/mes)
```bash
./scripts/provision_instance.sh cliente premium
```
**Estándar +**
- Voice WhatsApp
- Email Icebreaker
- Facturas automáticas

### 🔵 Pack NEXA ($399/mes)
```bash
./scripts/provision_instance.sh cliente nexa
```
**Premium +**
- Personal Assistant
- Videos VEO 3
- Análisis empresarial

---

## 🔧 Troubleshooting Común

### Problema: Instancia no arranca
```bash
cd instances/cliente1
docker-compose logs
# Buscar error específico
```

### Problema: SSL no funciona
```bash
# Verificar DNS
nslookup cliente1.tudominio.com

# Verificar Traefik
docker logs nexo_traefik | grep cliente1
```

### Problema: Webhooks no responden
```bash
# Test webhook
curl https://cliente1.tudominio.com/webhook/test

# Ver logs de la instancia
cd instances/cliente1
./manage.sh logs
```

### Problema: Alto uso de recursos
```bash
# Ver uso por instancia
docker stats

# Limitar recursos de una instancia
cd instances/cliente1
# Editar docker-compose.yml sección deploy.resources
./manage.sh restart
```

---

## 📈 Monitoreo

### Dashboard General
```
https://admin.tudominio.com
```

### Traefik Dashboard
```
https://traefik.tudominio.com
```

### Ver todas las instancias
```bash
docker ps | grep n8n_
```

### Estadísticas de recursos
```bash
docker stats --no-stream
```

---

## 🔐 Seguridad

### Cambiar contraseña del panel
```bash
nano .env
# Cambiar PANEL_ADMIN_PASSWORD
docker-compose restart control_panel
```

### Configurar firewall
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### Backups automáticos
Ya configurados. Se ejecutan cada 24h.

Ubicación: `instances/[cliente]/backups/`

---

## 💰 Billing y Facturación

### Ver uso por cliente
```bash
# API
curl https://admin.tudominio.com/api/instances/1/usage
```

### Generar reporte mensual
```bash
./scripts/generate_billing_report.sh 2025-01
```

---

## 🚨 Comandos de Emergencia

### Detener TODO
```bash
docker-compose down
```

### Reiniciar sistema completo
```bash
docker-compose restart
```

### Liberar espacio
```bash
docker system prune -a
```

### Backup completo
```bash
tar -czf backup_$(date +%Y%m%d).tar.gz instances/
```

---

## 📞 Contacto y Soporte

- **Email**: soporte@nexoai.com
- **Docs**: https://admin.tudominio.com/docs
- **Status**: https://status.tudominio.com

---

## 🎓 Recursos Adicionales

- [README Completo](README.md)
- [API Documentation](API.md)
- [Troubleshooting Avanzado](TROUBLESHOOTING.md)
- [Guía de Escalabilidad](SCALING.md)

---

**¿Dudas? Revisa el README completo o contacta soporte.**
