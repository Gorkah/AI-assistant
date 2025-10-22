#!/bin/bash
# NEXO IA - Instalación Rápida Completa
# wget https://raw.githubusercontent.com/YOUR_USER/AI-assistant/main/multi-tenant/quick_install.sh && chmod +x quick_install.sh && sudo bash quick_install.sh

clear
echo "╔════════════════════════════════════════╗"
echo "║   NEXO IA - Instalación Completa      ║"
echo "╚════════════════════════════════════════╝"
echo ""

[ "$EUID" -ne 0 ] && { echo "Error: Ejecuta como root"; exit 1; }

# Limpiar
echo "🧹 Limpiando instalación anterior..."
docker stop $(docker ps -aq) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null
rm -rf /opt/nexo-ai

# Instalar dependencias
echo "📦 Instalando dependencias..."
apt-get update -qq
apt-get install -y -qq curl wget git jq docker.io docker-compose ufw nodejs npm

# Obtener IPv4
echo "🌐 Detectando IP..."
VPS_IP=$(curl -4 -s ifconfig.me || curl -s https://api.ipify.org)
echo "IP: $VPS_IP"

# Configurar firewall
echo "🔥 Configurando firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 3000/tcp
ufw allow 5678:5698/tcp

# Crear estructura
echo "📁 Creando estructura..."
mkdir -p /opt/nexo-ai/{instances,scripts,panel/public/{css,js}}
cd /opt/nexo-ai

# Generar credenciales
POSTGRES_PASS=$(openssl rand -base64 20 | tr -d "=+/")
PANEL_PASS=$(openssl rand -base64 12)

# Crear .env
cat > .env <<EOF
VPS_IP=$VPS_IP
POSTGRES_ADMIN_USER=nexo_admin
POSTGRES_ADMIN_PASSWORD=$POSTGRES_PASS
BASE_PORT=5678
EOF

# Crear docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'
networks:
  nexo_network:
volumes:
  postgres_data:
services:
  postgres:
    image: postgres:15-alpine
    container_name: nexo_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: nexo_admin
      POSTGRES_PASSWORD: ${POSTGRES_ADMIN_PASSWORD}
      POSTGRES_DB: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - nexo_network
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "nexo_admin"]
      interval: 10s
EOF

# Descargar archivos del panel
echo "📥 Descargando panel web..."
wget -q https://raw.githubusercontent.com/YOUR_USER/AI-assistant/main/multi-tenant/panel_files.tar.gz -O /tmp/panel.tar.gz 2>/dev/null || echo "Creando panel local..."

# Si no hay conexión a GitHub, crear panel básico local
cat > panel/server.js <<'PANEL_EOF'
const http = require('http');
const { execSync } = require('child_process');
const fs = require('fs');

http.createServer((req, res) => {
  if (req.url === '/') {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.end(fs.readFileSync('/opt/nexo-ai/panel/index.html'));
  } else if (req.url === '/api/instances') {
    const dirs = fs.readdirSync('/opt/nexo-ai/instances');
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify(dirs));
  }
}).listen(3000, () => console.log('Panel en puerto 3000'));
PANEL_EOF

cat > panel/index.html <<'HTML_EOF'
<!DOCTYPE html>
<html>
<head><title>NEXO IA Panel</title>
<style>
body{font-family:Arial;max-width:1200px;margin:50px auto;padding:20px;background:#f5f5f5}
.card{background:white;padding:20px;margin:10px 0;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1)}
h1{color:#667eea}
button{background:#667eea;color:white;border:none;padding:10px 20px;border-radius:6px;cursor:pointer}
input,select{width:100%;padding:10px;margin:10px 0;border:1px solid #ddd;border-radius:4px}
</style>
</head>
<body>
<h1>🚀 NEXO IA - Panel de Control</h1>
<div class="card">
<h2>Crear Nueva Instancia</h2>
<input id="clientId" placeholder="ID del cliente (ej: empresa1)">
<select id="plan">
<option value="estandar">Estándar</option>
<option value="premium">Premium</option>
<option value="nexa">NEXA</option>
</select>
<button onclick="crear()">Crear Instancia</button>
</div>
<div id="result"></div>
<script>
function crear(){
  const id=document.getElementById('clientId').value;
  const plan=document.getElementById('plan').value;
  fetch('/api/create?id='+id+'&plan='+plan)
    .then(r=>r.text())
    .then(d=>document.getElementById('result').innerHTML='<div class="card">'+d+'</div>');
}
</script>
</body>
</html>
HTML_EOF

# Crear script de provision
cat > scripts/provision.sh <<'PROV_EOF'
#!/bin/bash
set -e
CLIENT_ID=$1
PLAN=$2
cd /opt/nexo-ai
source .env
[ -d "instances/$CLIENT_ID" ] && { echo "Ya existe"; exit 1; }
PORT=$((BASE_PORT + $(ls -1 instances 2>/dev/null | wc -l)))
mkdir -p "instances/$CLIENT_ID"/{data,workflows}
DB_NAME="n8n_${CLIENT_ID//-/_}"
DB_PASS=$(openssl rand -base64 20 | tr -d "=+/")
N8N_PASS=$(openssl rand -base64 12)
docker exec nexo_postgres psql -U nexo_admin -d postgres -c "CREATE DATABASE $DB_NAME;"
docker exec nexo_postgres psql -U nexo_admin -d postgres -c "CREATE USER $DB_NAME WITH PASSWORD '$DB_PASS';"
docker exec nexo_postgres psql -U nexo_admin -d postgres -c "GRANT ALL ON DATABASE $DB_NAME TO $DB_NAME;"
cat > "instances/$CLIENT_ID/.env" <<EOF
N8N_PORT=5678
WEBHOOK_URL=http://$VPS_IP:$PORT
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=nexo_postgres
DB_POSTGRESDB_DATABASE=$DB_NAME
DB_POSTGRESDB_USER=$DB_NAME
DB_POSTGRESDB_PASSWORD=$DB_PASS
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$N8N_PASS
EOF
cat > "instances/$CLIENT_ID/docker-compose.yml" <<DEOF
version: '3.8'
networks:
  nexo_network:
    external: true
services:
  n8n_$CLIENT_ID:
    image: n8nio/n8n:latest
    container_name: n8n_$CLIENT_ID
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./data:/home/node/.n8n
    networks:
      - nexo_network
    ports:
      - "$PORT:5678"
DEOF
cd "instances/$CLIENT_ID"
docker-compose up -d
echo "✅ Instancia creada"
echo "URL: http://$VPS_IP:$PORT"
echo "Usuario: admin"
echo "Contraseña: $N8N_PASS"
PROV_EOF

chmod +x scripts/provision.sh

# Iniciar servicios
echo "🚀 Iniciando servicios..."
docker network create nexo_network 2>/dev/null || true
docker-compose up -d
sleep 10

# Iniciar panel
echo "🌐 Iniciando panel web..."
cd panel
node server.js &
sleep 2

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   ✅ INSTALACIÓN COMPLETADA           ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Panel Web: http://$VPS_IP:3000"
echo ""
echo "Crear instancia:"
echo "  cd /opt/nexo-ai"
echo "  ./scripts/provision.sh cliente1 premium"
echo ""
echo "Ver estado:"
echo "  docker ps"
echo ""
