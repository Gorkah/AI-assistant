# 🔗 Configuración de Servicios Externos

## 1. EVOLUTION API (WhatsApp Business)

### Opción A: Evolution Cloud (Recomendado)
1. Registrarse en: https://evolution-api.com
2. Crear instancia
3. Conectar WhatsApp escaneando QR
4. Obtener API Key y URL
5. Configurar webhook en Evolution:
   ```
   URL: https://tu-dominio.com/webhook/424a3080-4473-47fb-8b32-6fdeede8f02b
   Events: All Messages
   ```

### Opción B: Self-hosted Evolution
```bash
# En el VPS
docker run -d \
  --name evolution-api \
  -p 8080:8080 \
  -e AUTHENTICATION_API_KEY=tu_api_key \
  atendai/evolution-api:latest
```

## 2. GOOGLE WORKSPACE

### Crear Proyecto en Google Cloud:
1. Ir a: https://console.cloud.google.com
2. Crear nuevo proyecto: "NEXO-IA-Automation"
3. Habilitar APIs:
   - Gmail API
   - Google Sheets API
   - Google Drive API
   - Google Calendar API

### Configurar OAuth 2.0:
1. APIs & Services → Credentials
2. Create Credentials → OAuth client ID
3. Application type: Web application
4. Authorized redirect URIs:
   ```
   https://tu-dominio.com/rest/oauth2-credential/callback
   ```
5. Guardar Client ID y Secret

### Configurar OAuth Consent Screen:
1. OAuth consent screen → External
2. App name: NEXO IA Automation
3. Support email: tu-email
4. Scopes necesarios:
   - gmail.send
   - gmail.readonly
   - spreadsheets
   - drive
   - calendar

## 3. AIRTABLE

### Crear Bases de Datos:
1. Login en Airtable
2. Crear workspace: "NEXO CRM"
3. Crear base: "CRM NEXO soluciones IA"

### Estructura de tablas:

#### Tabla: Leads
| Campo | Tipo |
|-------|------|
| Nombre | Single line text |
| Apellido | Single line text |
| Email | Email |
| Telefono | Phone |
| Empresa | Single line text |
| Estado | Single select |
| Score | Number |
| Clasificacion | Single select |
| FechaCreacion | Created time |

#### Tabla: Customers
| Campo | Tipo |
|-------|------|
| Nombre | Single line text |
| Email | Email |
| Telefono | Phone |
| Empresa | Single line text |
| Plan | Single select |
| FechaAlta | Date |

#### Tabla: EmailLog
| Campo | Tipo |
|-------|------|
| EmailID | Single line text |
| De | Email |
| Asunto | Single line text |
| Fecha | Date time |
| TipoRespuesta | Single select |
| Estado | Single select |

### Obtener Access Token:
1. Ir a: https://airtable.com/create/tokens
2. Create token
3. Scopes: data.records:read, data.records:write
4. Access: Seleccionar bases creadas
5. Guardar token

## 4. GOOGLE SHEETS

### Crear Hojas de Cálculo:

#### 1. NEXO_Leads_Database
1. Crear nueva hoja en Google Drive
2. Hoja 1 - "Leads":
   ```
   | Fecha | Nombre | Apellido | Email | Telefono | Empresa | Interes | Mensaje | Fuente | Score | Clasificacion | Estado |
   ```
3. Hoja 2 - "Estadisticas":
   ```
   | Fecha | Total Leads | Calientes | Tibios | Frios | Tasa Conversion |
   ```

#### 2. NEXO_Facturas_Control
1. Crear nueva hoja
2. Hoja 1 - "Facturas":
   ```
   | Fecha | Numero | Proveedor | Concepto | Base | IVA | Total | Estado | Categoria |
   ```

### Compartir hojas:
1. Share → Anyone with the link → Viewer
2. Copiar IDs de las hojas (están en la URL)

## 5. TELEGRAM BOT

### Crear Bot:
1. Abrir Telegram
2. Buscar: @BotFather
3. Comandos:
   ```
   /newbot
   Nombre: NEXO IA Assistant
   Username: nexo_ia_bot
   ```
4. Guardar token

### Obtener Chat IDs:
1. Enviar mensaje al bot creado
2. Visitar:
   ```
   https://api.telegram.org/bot[TU_TOKEN]/getUpdates
   ```
3. Buscar "chat":{"id": y copiar el ID

## 6. OPENAI

### Configurar cuenta:
1. Ir a: https://platform.openai.com
2. API Keys → Create new secret key
3. Configurar límites:
   - Usage limits: $100/month
   - Rate limits: 20 req/min

### Modelos necesarios:
- GPT-4 (para análisis complejos)
- GPT-4-mini (para respuestas rápidas)
- Whisper (transcripción de audio)
- TTS-1 (text to speech)

## 7. CONFIGURAR WEBHOOKS EN SERVICIOS

### Typeform/Tally (Formularios):
1. Settings → Integrations → Webhooks
2. URL: `https://tu-dominio.com/webhook/lead-capture-form`
3. Trigger: On form submit

### WhatsApp Business (Evolution):
1. Instance Settings → Webhooks
2. URL: `https://tu-dominio.com/webhook/424a3080-4473-47fb-8b32-6fdeede8f02b`
3. Events: messages.upsert

### Google Forms (Apps Script):
```javascript
function onFormSubmit(e) {
  var webhookUrl = 'https://tu-dominio.com/webhook/lead-capture-form';
  var formData = {
    nombre: e.values[1],
    apellido: e.values[2],
    email: e.values[3],
    telefono: e.values[4],
    empresa: e.values[5],
    mensaje: e.values[6],
    fuente: 'Google Forms'
  };
  
  UrlFetchApp.fetch(webhookUrl, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(formData)
  });
}
```

## 8. MONITOREO Y LOGS

### Configurar Uptime Monitor:
1. Usar UptimeRobot o similar
2. Monitor: `https://tu-dominio.com`
3. Check interval: 5 minutes
4. Alert contacts: tu-email

### Configurar logs en VPS:
```bash
# Ver logs de n8n
su - n8n -c 'pm2 logs n8n --lines 100'

# Configurar logrotate
cat > /etc/logrotate.d/n8n <<EOF
/home/n8n/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 0640 n8n n8n
    sharedscripts
    postrotate
        su - n8n -c 'pm2 reloadLogs'
    endscript
}
EOF
```
