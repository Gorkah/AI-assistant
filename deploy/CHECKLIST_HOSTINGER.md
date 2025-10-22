# ✅ CHECKLIST COMPLETO - Implementación en Hostinger

## 📋 FASE 1: PREPARACIÓN (30 min)

### Hostinger:
- [ ] Comprar VPS (mínimo KVM 2 - 8GB RAM)
- [ ] Seleccionar Ubuntu 22.04 LTS
- [ ] Anotar IP, usuario root y contraseña
- [ ] Comprar/configurar dominio (ej: n8n.tuempresa.com)
- [ ] Apuntar dominio a IP del VPS (DNS A record)

### APIs y Servicios:
- [ ] Crear cuenta OpenAI y obtener API Key
- [ ] Crear cuenta Airtable y generar Personal Access Token
- [ ] Crear proyecto en Google Cloud Console
- [ ] Configurar Evolution API o cuenta WhatsApp Business
- [ ] (Opcional) Crear bot de Telegram con BotFather

## 🔧 FASE 2: INSTALACIÓN BASE (45 min)

### Conectar al VPS:
```bash
ssh root@TU_IP_VPS
```

### Ejecutar script de instalación:
```bash
# Descargar script
wget https://raw.githubusercontent.com/tu-repo/hostinger_setup.sh
# O crear manualmente con nano
nano hostinger_setup.sh
# Pegar contenido del script

chmod +x hostinger_setup.sh
./hostinger_setup.sh
```

### Durante la instalación, proporcionar:
- [ ] Dominio (ej: n8n.tuempresa.com)
- [ ] Email para certificado SSL
- [ ] Esperar a que complete (10-15 min)

## 🔐 FASE 3: CONFIGURACIÓN DE APIS (20 min)

### Ejecutar configuración:
```bash
nano configure_apis.sh
# Pegar script de configuración
chmod +x configure_apis.sh
./configure_apis.sh
```

### Proporcionar credenciales:
- [ ] OpenAI API Key
- [ ] Evolution API URL y Key
- [ ] Airtable PAT y Base ID
- [ ] Google Client ID y Secret
- [ ] IDs de Google Sheets
- [ ] (Opcional) Telegram Bot Token
- [ ] Nuevo usuario y contraseña para n8n

## 📊 FASE 4: CONFIGURACIÓN EXTERNA (1 hora)

### Google Workspace:
- [ ] Crear proyecto en Google Cloud Console
- [ ] Habilitar APIs (Gmail, Sheets, Drive, Calendar)
- [ ] Configurar OAuth 2.0
- [ ] Agregar redirect URI: `https://tu-dominio.com/rest/oauth2-credential/callback`
- [ ] Configurar consent screen

### Airtable:
- [ ] Crear workspace "NEXO CRM"
- [ ] Crear base "CRM NEXO soluciones IA"
- [ ] Crear tablas: Leads, Customers, EmailLog, VoiceInteractions
- [ ] Configurar campos según esquema
- [ ] Generar Personal Access Token

### Google Sheets:
- [ ] Crear hoja "NEXO_Leads_Database"
- [ ] Crear hoja "NEXO_Facturas_Control"
- [ ] Configurar columnas según template
- [ ] Obtener IDs de las hojas

### Evolution API (WhatsApp):
- [ ] Registrarse en Evolution Cloud o instalar self-hosted
- [ ] Crear instancia
- [ ] Conectar WhatsApp (escanear QR)
- [ ] Configurar webhook

### Telegram (Opcional):
- [ ] Crear bot con @BotFather
- [ ] Obtener token
- [ ] Obtener chat IDs necesarios

## 📦 FASE 5: IMPORTACIÓN DE WORKFLOWS (45 min)

### Preparar archivos:
```bash
# En tu PC local
cd C:\Users\thePalms\Documents\GitHub\AI-assistant
# Comprimir workflows
tar -czf workflows.tar.gz LEADS/*.json Recepcionista/*.json FACTURAS/*.json ICEBREAKER/*.json "PERSONAL ASSISTANT"/*.json "VIDEOS VEO 3"/*.json ANALYTICS/*.json

# Subir al VPS
scp workflows.tar.gz root@TU_IP_VPS:/home/n8n/workflows/
```

### En n8n Web:
- [ ] Acceder a https://tu-dominio.com
- [ ] Login con credenciales configuradas
- [ ] Workflows → Import from File

### Importar por paquete:

#### 🟢 Pack Estándar:
- [ ] `Agente_recepcionista_NEXO.json`
- [ ] `Agente_Atencion_Gmail.json`
- [ ] `Captacion_Leads_Formulario.json`

#### 🟡 Pack Premium:
- [ ] `Agente_Voice_WhatsApp.json`
- [ ] `Email_Icebreaker_Personalizado.json`
- [ ] `Automatiza facturas.json`

#### 🔵 Pack NEXA:
- [ ] `Telegram_asistant.json`
- [ ] `Personal_Assistant_whatsapp.json`
- [ ] `VEO_3_VIDEOS.json`
- [ ] `Agente_Analisis_Empresarial.json`

## 🔑 FASE 6: CONFIGURAR CREDENCIALES EN N8N (30 min)

### Para cada workflow importado:
- [ ] Abrir workflow
- [ ] Identificar nodos con ⚠️ (necesitan credenciales)
- [ ] Configurar cada credencial:
  - [ ] OpenAI
  - [ ] Gmail OAuth
  - [ ] Google Sheets OAuth
  - [ ] Evolution API
  - [ ] Airtable
  - [ ] Telegram (si aplica)

## 🔗 FASE 7: CONFIGURAR WEBHOOKS (15 min)

### En servicios externos:

#### Typeform/Tally:
- [ ] Settings → Webhooks
- [ ] URL: `https://tu-dominio.com/webhook/lead-capture-form`

#### Evolution API:
- [ ] Instance Settings → Webhooks
- [ ] URL: `https://tu-dominio.com/webhook/424a3080-4473-47fb-8b32-6fdeede8f02b`

#### Google Forms (si usas):
- [ ] Tools → Script editor
- [ ] Agregar script de webhook
- [ ] Configurar trigger onFormSubmit

## ✅ FASE 8: TESTING Y VALIDACIÓN (30 min)

### Ejecutar validación:
```bash
# En el VPS
nano testing_validation.sh
# Pegar script de testing
chmod +x testing_validation.sh
./testing_validation.sh tu-dominio.com
```

### Verificar resultados:
- [ ] Todos los servicios activos
- [ ] SSL funcionando
- [ ] APIs configuradas
- [ ] Webhooks accesibles
- [ ] Recursos suficientes

## 🧪 FASE 9: PRUEBAS FUNCIONALES (1 hora)

### Test Pack Estándar:
- [ ] Enviar mensaje WhatsApp → verificar respuesta
- [ ] Enviar email a Gmail configurado → verificar procesamiento
- [ ] Enviar formulario de prueba → verificar lead en Sheets/Airtable

### Test Pack Premium:
- [ ] Enviar audio WhatsApp → verificar transcripción y respuesta
- [ ] Ejecutar campaña Icebreaker con 1 contacto de prueba
- [ ] Subir factura a Drive → verificar extracción

### Test Pack NEXA:
- [ ] Enviar comando a Telegram bot
- [ ] Verificar análisis empresarial programado
- [ ] Probar generación de video (si configurado)

## 🚀 FASE 10: PUESTA EN PRODUCCIÓN (15 min)

### Activar workflows:
- [ ] Abrir cada workflow
- [ ] Cambiar de "Inactive" a "Active"
- [ ] Verificar que no hay errores

### Configurar monitoreo:
- [ ] Configurar UptimeRobot para https://tu-dominio.com
- [ ] Configurar alertas por email
- [ ] Verificar logs: `pm2 logs n8n`

### Backups:
- [ ] Verificar backup automático configurado
- [ ] Test manual: `/home/n8n/backup.sh`
- [ ] Verificar archivo en `/home/n8n/backups/`

## 📈 FASE 11: OPTIMIZACIÓN (Opcional)

### Performance:
- [ ] Configurar Redis para cache (si necesario)
- [ ] Ajustar workers de PM2
- [ ] Optimizar timeouts de webhooks

### Seguridad:
- [ ] Cambiar puerto SSH
- [ ] Configurar fail2ban
- [ ] Habilitar 2FA en n8n (Enterprise)
- [ ] Rotar API keys regularmente

## 📞 SOPORTE Y MANTENIMIENTO

### Comandos útiles:
```bash
# Ver logs
pm2 logs n8n

# Reiniciar n8n
pm2 restart n8n

# Ver estado
pm2 status

# Backup manual
/home/n8n/backup.sh

# Ver uso de recursos
htop
```

### Troubleshooting común:

**Webhook no funciona:**
- Verificar URL correcta
- Verificar firewall (puerto abierto)
- Revisar logs: `pm2 logs n8n`

**Error de credenciales:**
- Verificar en n8n → Settings → Credentials
- Re-autorizar OAuth si necesario
- Verificar API keys válidas

**Alto uso de recursos:**
- Limitar ejecuciones paralelas en n8n
- Aumentar recursos del VPS
- Optimizar workflows

## ✅ CONFIRMACIÓN FINAL

### Sistema operativo cuando:
- [ ] Validación muestra >90% tests pasados
- [ ] Todos los workflows activos sin errores
- [ ] Webhooks respondiendo correctamente
- [ ] Al menos 1 prueba exitosa por workflow
- [ ] Backups funcionando
- [ ] Monitoreo activo

## 📊 TIEMPO TOTAL ESTIMADO

- **Configuración básica:** 2-3 horas
- **Configuración completa (todos los packs):** 4-5 horas
- **Con experiencia previa:** 2-3 horas
- **Primera vez:** 5-6 horas

---

**¡FELICIDADES! 🎉**
Tu sistema NEXO IA está completamente operativo en Hostinger.

**Soporte:**
- Email: soporte@nexosoluciones.com
- Documentación: /README.md
- Logs: `pm2 logs n8n`
