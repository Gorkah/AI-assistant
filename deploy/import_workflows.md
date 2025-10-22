# 📦 Guía de Importación de Workflows

## 1. PREPARACIÓN DE ARCHIVOS

### Desde tu PC local:
```bash
# Comprimir los workflows
cd C:\Users\thePalms\Documents\GitHub\AI-assistant
tar -czf workflows.tar.gz *.json LEADS/*.json Recepcionista/*.json FACTURAS/*.json ICEBREAKER/*.json "PERSONAL ASSISTANT"/*.json "VIDEOS VEO 3"/*.json ANALYTICS/*.json
```

### Subir al VPS:
```bash
# Usar SCP desde PowerShell
scp workflows.tar.gz root@TU_IP_VPS:/home/n8n/workflows/

# O usar FileZilla/WinSCP con estos datos:
# - Host: TU_IP_VPS
# - Puerto: 22
# - Usuario: root
# - Contraseña: tu_password
```

## 2. IMPORTAR EN N8N (Interfaz Web)

### Acceder a n8n:
1. Abre navegador: `https://tu-dominio.com`
2. Login con credenciales configuradas

### Importar cada workflow:

#### 🟢 PACK ESTÁNDAR
1. **Agente WhatsApp**
   - Workflows → Import from File
   - Seleccionar: `Agente_recepcionista_NEXO.json`
   - Configurar credenciales:
     - Evolution API
     - OpenAI
     - Airtable

2. **Agente Gmail**
   - Importar: `Agente_Atencion_Gmail.json`
   - Configurar:
     - Gmail OAuth2
     - OpenAI
     - Airtable

3. **Captación Leads**
   - Importar: `Captacion_Leads_Formulario.json`
   - Configurar:
     - Google Sheets
     - OpenAI
     - Gmail

#### 🟡 PACK PREMIUM (adicional)
4. **Voice WhatsApp**
   - Importar: `Agente_Voice_WhatsApp.json`
   - Configurar:
     - Whisper API
     - TTS API
     - Evolution API

5. **Email Icebreaker**
   - Importar: `Email_Icebreaker_Personalizado.json`
   - Configurar:
     - Gmail
     - Airtable
     - OpenAI

6. **Facturas**
   - Importar: `Automatiza facturas.json`
   - Configurar:
     - Google Drive
     - Gemini API
     - Google Sheets

#### 🔵 PACK NEXA (adicional)
7. **Personal Assistant**
   - Importar: `Telegram_asistant.json`
   - Importar: `Personal_Assistant_whatsapp.json`
   - Configurar:
     - Telegram Bot
     - Google Calendar
     - WhatsApp

8. **Videos VEO 3**
   - Importar: `VEO_3_VIDEOS.json`
   - Configurar:
     - VEO 3 API
     - OpenAI

9. **Analytics**
   - Importar: `Agente_Analisis_Empresarial.json`
   - Configurar:
     - Google Analytics
     - Todas las integraciones previas

## 3. CONFIGURAR CREDENCIALES EN N8N

### OpenAI:
1. Settings → Credentials → Create New
2. Type: OpenAI
3. API Key: tu_key
4. Save

### Gmail OAuth:
1. Settings → Credentials → Create New
2. Type: Google OAuth2
3. Seguir proceso OAuth
4. Autorizar acceso

### Evolution API:
1. Settings → Credentials → Create New
2. Type: HTTP Header Auth
3. Header Name: apikey
4. Header Value: tu_evolution_key
5. Save

### Airtable:
1. Settings → Credentials → Create New
2. Type: Airtable API
3. Access Token: tu_pat
4. Save

### Telegram:
1. Settings → Credentials → Create New
2. Type: Telegram
3. Access Token: tu_bot_token
4. Save

## 4. ACTUALIZAR WEBHOOKS

Para cada workflow con webhook:

### Lead Capture:
```
https://tu-dominio.com/webhook/lead-capture-form
```

### WhatsApp Reception:
```
https://tu-dominio.com/webhook/424a3080-4473-47fb-8b32-6fdeede8f02b
```

### Voice Messages:
```
https://tu-dominio.com/webhook/voice-webhook
```

## 5. ACTIVAR WORKFLOWS

1. Abrir cada workflow
2. Click en "Inactive" → cambiar a "Active"
3. Verificar que no hay errores

## 6. CONFIGURAR TRIGGERS

### Para workflows programados:
1. Abrir workflow
2. Doble click en nodo Schedule Trigger
3. Ajustar horarios según zona horaria
4. Guardar cambios
