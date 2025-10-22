# 🚀 INSTALACIÓN COMPLETA - VPS HOSTINGER SIN DOMINIO

## ✅ Guía paso a paso para instalar el sistema multi-tenant usando SOLO IP

---

## 📋 **ANTES DE EMPEZAR**

### Lo que necesitas:
- ✅ VPS Hostinger con Ubuntu 22.04
- ✅ IP pública del VPS
- ✅ Acceso SSH (root o sudo)
- ✅ Puertos disponibles: 3000, 5678-5698

### Lo que NO necesitas:
- ❌ Dominio
- ❌ Certificados SSL
- ❌ Configuración DNS

---

## 🔧 **PASO 1: Conectar al VPS**

Desde tu PC (Windows):

**Opción A: PowerShell**
```powershell
ssh root@TU_IP_HOSTINGER
# Ejemplo: ssh root@123.456.789.123
```

**Opción B: PuTTY**
1. Descargar PuTTY: https://www.putty.org/
2. Host: TU_IP_HOSTINGER
3. Port: 22
4. Conectar

---

## 🧹 **PASO 2: Limpiar Instalación Anterior**

Una vez conectado al VPS, ejecuta:

```bash
# Ver si hay contenedores corriendo
docker ps -a

# Detener todos los contenedores
docker stop $(docker ps -aq) 2>/dev/null

# Eliminar contenedores
docker rm $(docker ps -aq) 2>/dev/null

# Limpiar imágenes y volúmenes no usados
docker system prune -a -f

# Si necesitas eliminar TODO (incluyendo datos):
# docker volume rm $(docker volume ls -q) 2>/dev/null
```

---

## 📦 **PASO 3: Instalar Docker (si no está instalado)**

```bash
# Actualizar sistema
apt update && apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verificar instalación
docker --version
docker-compose --version
```

---

## 📂 **PASO 4: Clonar el Repositorio**

```bash
# Ir a directorio /opt
cd /opt

# Clonar repositorio
git clone https://github.com/tu-usuario/AI-assistant.git

# Si no tienes git:
apt install git -y
git clone https://github.com/tu-usuario/AI-assistant.git

# Entrar a carpeta multi-tenant
cd AI-assistant/multi-tenant
```

---

## ⚙️ **PASO 5: Configurar Variables de Entorno**

```bash
# Copiar template
cp .env.nossl .env

# Editar con nano
nano .env
```

**Edita SOLO estas líneas:**
```bash
# Cambiar por la IP PÚBLICA de tu VPS Hostinger
VPS_IP=123.456.789.123

# Cambiar contraseñas (importante!)
POSTGRES_ADMIN_PASSWORD=TuPasswordSegura123!
REDIS_PASSWORD=OtraPasswordSegura456!
PANEL_ADMIN_PASSWORD=PasswordPanel789!
```

**Guardar:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

## 🚀 **PASO 6: Obtener IP Pública del VPS**

```bash
# Ver tu IP pública
curl ifconfig.me

# O también:
hostname -I | awk '{print $1}'
```

Copia esa IP y asegúrate de ponerla en `VPS_IP` del archivo `.env`

---

## 🔓 **PASO 7: Abrir Puertos en Firewall**

### En Hostinger hPanel:

1. Ir a tu VPS en hPanel
2. **Firewall** o **Seguridad**
3. Agregar reglas:

```
Puerto 3000  → TCP → Panel de Control
Puerto 5678  → TCP → Cliente 1
Puerto 5679  → TCP → Cliente 2
Puerto 5680  → TCP → Cliente 3
...
Puerto 5698  → TCP → Cliente 20
```

### O por línea de comandos (UFW):

```bash
# Habilitar firewall
ufw allow 22/tcp    # SSH
ufw allow 3000/tcp  # Panel
ufw allow 5678:5698/tcp  # n8n instancias
ufw enable
ufw status
```

---

## 🎯 **PASO 8: Iniciar Servicios Base**

```bash
# Asegurarte de estar en la carpeta correcta
cd /opt/AI-assistant/multi-tenant

# Usar el docker-compose sin SSL
docker-compose -f docker-compose-nossl.yml up -d

# Ver logs
docker-compose -f docker-compose-nossl.yml logs -f
```

**Espera 1-2 minutos** hasta ver:
```
nexo_control_panel | Running on http://0.0.0.0:3000
nexo_postgres      | database system is ready to accept connections
```

Presiona `Ctrl + C` para salir de los logs.

---

## ✅ **PASO 9: Verificar que Funciona**

### Desde tu navegador (en tu PC):

```
http://TU_IP:3000
```

Deberías ver el panel de login.

**Credenciales:**
- Usuario: `admin`
- Contraseña: la que pusiste en `PANEL_ADMIN_PASSWORD`

---

## 🎨 **PASO 10: Crear Primera Instancia de Cliente**

### Opción A: Desde el panel web

1. Ir a `http://TU_IP:3000`
2. Login
3. Click "Nueva Instancia"
4. Llenar formulario
5. Crear

### Opción B: Por línea de comandos (más rápido)

```bash
# Dar permisos al script
chmod +x scripts/provision_nossl.sh

# Crear instancia Pack Estándar
./scripts/provision_nossl.sh cliente1 estandar

# O Pack Premium
./scripts/provision_nossl.sh empresa2 premium

# O Pack NEXA
./scripts/provision_nossl.sh corporativo nexa
```

**Ejemplo de output:**
```
================================================
   ✅ INSTANCIA CREADA EXITOSAMENTE
================================================

Cliente: cliente1
Plan: estandar
URL: http://123.456.789.123:5678
Usuario: admin
Contraseña: X7k9mP2n5Q

Workflows: 3 importados
```

---

## 🌐 **PASO 11: Acceder a la Instancia del Cliente**

Abre en tu navegador:
```
http://TU_IP:5678
```

**Login:**
- Usuario: `admin`
- Contraseña: la que te dio el script (ejemplo: `X7k9mP2n5Q`)

---

## 🔑 **PASO 12: Configurar APIs en n8n**

Una vez dentro de n8n:

### 1. Ir a Settings → Credentials

### 2. Crear credencial de OpenAI:
- Click **"Create New Credential"**
- Buscar **"OpenAI"**
- Pegar tu API Key: `sk-proj-...`
- Nombre: `OpenAI API`
- Save

### 3. Crear credencial de Evolution API:
- Click **"Create New Credential"**
- Buscar **"HTTP Header Auth"**
- Header Name: `apikey`
- Header Value: tu key de Evolution
- Nombre: `Evolution API`
- Save

### 4. Crear credencial de Airtable:
- Click **"Create New Credential"**
- Buscar **"Airtable Personal Access Token"**
- Pegar tu token
- Nombre: `Airtable`
- Save

### 5. Crear credencial de Google:
- Click **"Create New Credential"**
- Buscar **"Google OAuth2"**
- Client ID y Secret
- Hacer flujo OAuth
- Save

---

## 📝 **PASO 13: Configurar Workflows**

### 1. Ver workflows importados:
- En n8n, ir a **Workflows**
- Verás 3, 6 o 10 workflows según el plan

### 2. Abrir cada workflow:
- Click en el workflow
- Verás nodos con ⚠️ (sin credenciales)

### 3. Asignar credenciales:
- Doble click en nodo con ⚠️
- En "Credential to connect with", seleccionar la que creaste
- Save workflow

### 4. Activar workflow:
- Toggle en la esquina: **Inactive → Active**

---

## 🎯 **PASO 14: Crear Más Instancias**

```bash
# Cliente 2 (se asignará puerto 5679)
./scripts/provision_nossl.sh cliente2 premium

# Cliente 3 (se asignará puerto 5680)
./scripts/provision_nossl.sh cliente3 nexa

# Ver todas las instancias
docker ps | grep n8n_
```

Cada cliente tendrá:
- **URL diferente:** `http://TU_IP:567X`
- **Credenciales únicas**
- **Base de datos separada**
- **Workflows según su plan**

---

## 📊 **GESTIÓN DIARIA**

### Ver todas las instancias:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Gestionar una instancia específica:
```bash
cd /opt/AI-assistant/multi-tenant/instances/cliente1

# Ver logs
./manage.sh logs

# Reiniciar
./manage.sh restart

# Detener
./manage.sh stop

# Iniciar
./manage.sh start

# Backup
./manage.sh backup
```

### Ver logs en tiempo real:
```bash
docker logs -f n8n_cliente1
```

### Reiniciar todo el sistema:
```bash
cd /opt/AI-assistant/multi-tenant
docker-compose -f docker-compose-nossl.yml restart
```

---

## 🔧 **TROUBLESHOOTING**

### ❌ "No puedo acceder a http://TU_IP:3000"

**Solución:**
```bash
# Verificar que el contenedor esté corriendo
docker ps | grep control_panel

# Ver logs
docker logs nexo_control_panel

# Verificar firewall
ufw status

# Verificar que el puerto esté escuchando
netstat -tulpn | grep 3000
```

### ❌ "Error al crear instancia"

**Solución:**
```bash
# Ver logs del panel
docker logs nexo_control_panel

# Verificar PostgreSQL
docker exec nexo_postgres psql -U nexo_admin -l

# Reiniciar servicios base
docker-compose -f docker-compose-nossl.yml restart
```

### ❌ "n8n no carga"

**Solución:**
```bash
# Ver logs de la instancia
cd instances/cliente1
./manage.sh logs

# Reiniciar
./manage.sh restart

# Verificar puerto
netstat -tulpn | grep 5678
```

### ❌ "Puerto ya en uso"

**Solución:**
```bash
# Ver qué está usando el puerto
lsof -i :5678

# Matar proceso si es necesario
kill -9 PID

# O cambiar puerto en docker-compose.yml de la instancia
```

---

## 🚨 **COMANDOS DE EMERGENCIA**

### Detener TODO:
```bash
docker stop $(docker ps -aq)
```

### Reiniciar TODO:
```bash
cd /opt/AI-assistant/multi-tenant
docker-compose -f docker-compose-nossl.yml restart
```

### Backup completo:
```bash
tar -czf backup_$(date +%Y%m%d).tar.gz /opt/AI-assistant/multi-tenant/instances/
```

### Restaurar instancia:
```bash
cd instances/cliente1
tar -xzf backups/backup_20250122_120000.tar.gz
./manage.sh restart
```

---

## 📊 **RESUMEN DE URLS**

```
Panel Control:    http://TU_IP:3000
Cliente 1:        http://TU_IP:5678
Cliente 2:        http://TU_IP:5679
Cliente 3:        http://TU_IP:5680
...
Cliente 20:       http://TU_IP:5698
```

---

## 🎯 **CHECKLIST FINAL**

- [ ] VPS conectado via SSH
- [ ] Docker y Docker Compose instalados
- [ ] Repositorio clonado en `/opt/AI-assistant`
- [ ] Archivo `.env` configurado con tu IP
- [ ] Puertos abiertos en firewall (3000, 5678-5698)
- [ ] Servicios base corriendo (PostgreSQL, Redis, Panel)
- [ ] Panel accesible en `http://TU_IP:3000`
- [ ] Primera instancia creada
- [ ] n8n accesible en `http://TU_IP:5678`
- [ ] Workflows importados
- [ ] Credenciales de APIs configuradas en n8n
- [ ] Workflows activados

---

## 💰 **GESTIÓN DE CLIENTES**

### Crear nuevo cliente:
```bash
./scripts/provision_nossl.sh nombre_cliente plan
```

### Entregar acceso al cliente:
```
URL: http://TU_IP:567X
Usuario: admin
Contraseña: [la que generó el script]

IMPORTANTE: El cliente debe configurar sus API Keys en n8n:
1. Settings → Credentials
2. Crear credenciales de OpenAI, Evolution, etc.
3. Asignar a cada workflow
4. Activar workflows
```

### Facturación mensual:
- Pack Estándar: $99/mes
- Pack Premium: $199/mes
- Pack NEXA: $399/mes

---

## 📞 **SOPORTE**

Si tienes problemas:

1. **Ver logs:** `docker logs [nombre_contenedor]`
2. **Revisar firewall:** `ufw status`
3. **Verificar servicios:** `docker ps`
4. **Reiniciar:** `docker-compose restart`

---

## 🎉 **¡LISTO!**

Tu sistema multi-tenant está funcionando. Ahora puedes:
- ✅ Crear instancias ilimitadas (hasta 20 por defecto)
- ✅ Cada cliente totalmente aislado
- ✅ Gestión centralizada desde el panel
- ✅ Workflows pre-configurados
- ✅ Backups automáticos

**¡Comienza a vender tus packs!** 🚀
