"""
NEXO IA - Panel de Control Multi-Tenant
Sistema de aprovisionamiento automático de instancias n8n
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import subprocess
import json
import os
import secrets
import string

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', secrets.token_hex(32))
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

BASE_DOMAIN = os.getenv('BASE_DOMAIN', 'srv869945.hstgr.cloud')
N8N_BASE_PATH = '/srv/n8n'

# ================================================
# MODELOS
# ================================================

class Instance(db.Model):
    __tablename__ = 'instances'
    
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.String(100), unique=True, nullable=False, index=True)
    plan = db.Column(db.String(20), nullable=False)
    status = db.Column(db.String(20), default='active')
    url = db.Column(db.String(255), nullable=False)
    
    # Información del cliente
    company_name = db.Column(db.String(255))
    contact_email = db.Column(db.String(255))
    contact_phone = db.Column(db.String(50))
    
    # Credenciales
    admin_user = db.Column(db.String(100))
    admin_password = db.Column(db.String(255))
    
    # Configuración
    cpu_limit = db.Column(db.Float, default=1.0)
    memory_limit = db.Column(db.String(10), default='2g')
    use_postgres = db.Column(db.Boolean, default=False)
    postgres_db = db.Column(db.String(100))
    
    # Servicios adicionales
    has_evolution = db.Column(db.Boolean, default=False)
    evolution_url = db.Column(db.String(255))
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_backup = db.Column(db.DateTime)
    
    def to_dict(self):
        return {
            'id': self.id,
            'client_id': self.client_id,
            'plan': self.plan,
            'status': self.status,
            'url': self.url,
            'company_name': self.company_name,
            'contact_email': self.contact_email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'use_postgres': self.use_postgres,
            'has_evolution': self.has_evolution
        }

class ApiCredential(db.Model):
    __tablename__ = 'api_credentials'
    
    id = db.Column(db.Integer, primary_key=True)
    instance_id = db.Column(db.Integer, db.ForeignKey('instances.id'), nullable=False)
    service = db.Column(db.String(50), nullable=False)
    credential_data = db.Column(db.Text)
    is_configured = db.Column(db.Boolean, default=False)
    
    instance = db.relationship('Instance', backref=db.backref('credentials', lazy=True))

# ================================================
# CONFIGURACIÓN DE PACKS
# ================================================

PACK_CONFIG = {
    'estandar': {
        'name': 'Pack Estándar',
        'price': 99,
        'workflows': [
            'Recepcionista/Agente_recepcionista_NEXO.json',
            'Recepcionista/Agente_Atencion_Gmail.json',
            'LEADS/Captacion_Leads_Formulario.json'
        ],
        'required_apis': ['openai', 'gmail', 'google_sheets', 'evolution_api'],
        'use_postgres': False,
        'cpu': 1.0,
        'memory': '2g'
    },
    'premium': {
        'name': 'Pack Premium',
        'price': 199,
        'workflows': [
            'Recepcionista/Agente_recepcionista_NEXO.json',
            'Recepcionista/Agente_Atencion_Gmail.json',
            'Recepcionista/Agente_Voice_WhatsApp.json',
            'LEADS/Captacion_Leads_Formulario.json',
            'ICEBREAKER/Email_Icebreaker_Personalizado.json',
            'FACTURAS/Automatiza facturas.json'
        ],
        'required_apis': ['openai', 'gmail', 'google_sheets', 'evolution_api', 'airtable', 'whisper', 'tts'],
        'use_postgres': True,
        'cpu': 1.5,
        'memory': '3g'
    },
    'nexa': {
        'name': 'Pack NEXA',
        'price': 399,
        'workflows': [
            'Recepcionista/Agente_recepcionista_NEXO.json',
            'Recepcionista/Agente_Atencion_Gmail.json',
            'Recepcionista/Agente_Voice_WhatsApp.json',
            'LEADS/Captacion_Leads_Formulario.json',
            'ICEBREAKER/Email_Icebreaker_Personalizado.json',
            'FACTURAS/Automatiza facturas.json',
            'PERSONAL ASSISTANT/Telegram_asistant.json',
            'PERSONAL ASSISTANT/Personal_Assistant_whatsapp.json',
            'VIDEOS VEO 3/VEO_3_VIDEOS.json',
            'ANALYTICS/Agente_Analisis_Empresarial.json'
        ],
        'required_apis': ['openai', 'gmail', 'google_sheets', 'evolution_api', 'airtable', 
                         'whisper', 'tts', 'telegram', 'veo3', 'google_analytics'],
        'use_postgres': True,
        'cpu': 2.0,
        'memory': '4g',
        'deploy_evolution': True
    }
}

# ================================================
# UTILIDADES
# ================================================

def generate_password(length=16):
    """Generar contraseña segura"""
    chars = string.ascii_letters + string.digits + "!@#$%^&*()"
    return ''.join(secrets.choice(chars) for _ in range(length))

def run_command(cmd, cwd=None):
    """Ejecutar comando shell"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=300
        )
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def create_docker_compose(client_id, plan_config, db_config=None, evolution_config=None):
    """Generar docker-compose.yml según el pack"""
    
    admin_password = generate_password()
    
    compose = {
        'version': '3.8',
        'services': {},
        'volumes': {},
        'networks': {
            'root_default': {
                'external': True
            }
        }
    }
    
    # Servicio PostgreSQL si es necesario
    if plan_config.get('use_postgres'):
        db_name = f"n8n_{client_id.replace('-', '_')}"
        db_user = f"n8n_{client_id.replace('-', '_')}"
        db_password = generate_password(24)
        
        compose['services'][f'postgres_{client_id}'] = {
            'image': 'postgres:15-alpine',
            'container_name': f'postgres_{client_id}',
            'restart': 'unless-stopped',
            'environment': {
                'POSTGRES_DB': db_name,
                'POSTGRES_USER': db_user,
                'POSTGRES_PASSWORD': db_password
            },
            'volumes': [f'postgres_data_{client_id}:/var/lib/postgresql/data'],
            'networks': ['root_default'],
            'healthcheck': {
                'test': ['CMD-SHELL', f'pg_isready -U {db_user}'],
                'interval': '10s',
                'timeout': '5s',
                'retries': 5
            }
        }
        
        compose['volumes'][f'postgres_data_{client_id}'] = None
        db_config = {'db_name': db_name, 'db_user': db_user, 'db_password': db_password}
    
    # Servicio Evolution API si es NEXA
    if plan_config.get('deploy_evolution'):
        compose['services'][f'evolution_{client_id}'] = {
            'image': 'atendai/evolution-api:latest',
            'container_name': f'evolution_{client_id}',
            'restart': 'unless-stopped',
            'environment': {
                'SERVER_URL': f'https://evolution-{client_id}.{BASE_DOMAIN}',
                'AUTHENTICATION_API_KEY': generate_password(32)
            },
            'volumes': [f'evolution_data_{client_id}:/evolution/instances'],
            'networks': ['root_default'],
            'labels': [
                'traefik.enable=true',
                f'traefik.http.routers.evolution-{client_id}.rule=Host(`evolution-{client_id}.{BASE_DOMAIN}`)',
                'traefik.http.routers.evolution-{client_id}.entrypoints=websecure',
                'traefik.http.routers.evolution-{client_id}.tls=true',
                'traefik.http.routers.evolution-{client_id}.tls.certresolver=mytlschallenge',
                f'traefik.http.services.evolution-{client_id}.loadbalancer.server.port=8080'
            ]
        }
        compose['volumes'][f'evolution_data_{client_id}'] = None
        
        evolution_config = {
            'url': f'https://evolution-{client_id}.{BASE_DOMAIN}',
            'api_key': compose['services'][f'evolution_{client_id}']['environment']['AUTHENTICATION_API_KEY']
        }
    
    # Servicio n8n principal
    n8n_env = {
        'N8N_HOST': f'{client_id}.{BASE_DOMAIN}',
        'N8N_PORT': '5678',
        'N8N_PROTOCOL': 'http',
        'WEBHOOK_URL': f'https://{client_id}.{BASE_DOMAIN}/',
        'NODE_ENV': 'production',
        'N8N_BASIC_AUTH_ACTIVE': 'true',
        'N8N_BASIC_AUTH_USER': f'{client_id}_admin',
        'N8N_BASIC_AUTH_PASSWORD': admin_password,
        'GENERIC_TIMEZONE': 'Europe/Madrid',
        'EXECUTIONS_DATA_SAVE_ON_ERROR': 'all',
        'EXECUTIONS_DATA_SAVE_ON_SUCCESS': 'all',
        'EXECUTIONS_DATA_MAX_AGE': '336'
    }
    
    # Configurar PostgreSQL si está disponible
    if db_config:
        n8n_env.update({
            'DB_TYPE': 'postgresdb',
            'DB_POSTGRESDB_HOST': f'postgres_{client_id}',
            'DB_POSTGRESDB_PORT': '5432',
            'DB_POSTGRESDB_DATABASE': db_config['db_name'],
            'DB_POSTGRESDB_USER': db_config['db_user'],
            'DB_POSTGRESDB_PASSWORD': db_config['db_password']
        })
    
    compose['services'][f'n8n_{client_id}'] = {
        'image': 'docker.n8n.io/n8nio/n8n:latest',
        'container_name': f'n8n_{client_id}',
        'restart': 'unless-stopped',
        'environment': n8n_env,
        'volumes': [f'n8n_data_{client_id}:/home/node/.n8n'],
        'networks': ['root_default'],
        'labels': [
            'traefik.enable=true',
            f'traefik.http.routers.n8n-{client_id}.rule=Host(`{client_id}.{BASE_DOMAIN}`)',
            'traefik.http.routers.n8n-{client_id}.entrypoints=websecure',
            'traefik.http.routers.n8n-{client_id}.tls=true',
            'traefik.http.routers.n8n-{client_id}.tls.certresolver=mytlschallenge',
            f'traefik.http.routers.n8n-{client_id}.middlewares=n8n-{client_id}@docker',
            f'traefik.http.middlewares.n8n-{client_id}.headers.SSLRedirect=true',
            f'traefik.http.middlewares.n8n-{client_id}.headers.STSSeconds=315360000',
            f'traefik.http.middlewares.n8n-{client_id}.headers.browserXSSFilter=true',
            f'traefik.http.middlewares.n8n-{client_id}.headers.contentTypeNosniff=true',
            f'traefik.http.middlewares.n8n-{client_id}.headers.forceSTSHeader=true',
            f'traefik.http.middlewares.n8n-{client_id}.headers.SSLHost={client_id}.{BASE_DOMAIN}',
            f'traefik.http.middlewares.n8n-{client_id}.headers.STSIncludeSubdomains=true',
            f'traefik.http.middlewares.n8n-{client_id}.headers.STSPreload=true'
        ]
    }
    
    if db_config:
        compose['services'][f'n8n_{client_id}']['depends_on'] = {
            f'postgres_{client_id}': {'condition': 'service_healthy'}
        }
    
    compose['volumes'][f'n8n_data_{client_id}'] = None
    
    return compose, admin_password, db_config, evolution_config

def deploy_instance(client_id, plan, company_name='', contact_email='', apis=None):
    """Desplegar nueva instancia"""
    
    try:
        # Validar que no exista
        if Instance.query.filter_by(client_id=client_id).first():
            return False, "El cliente ya existe"
        
        plan_config = PACK_CONFIG.get(plan)
        if not plan_config:
            return False, "Plan inválido"
        
        # Crear directorio
        client_dir = os.path.join(N8N_BASE_PATH, client_id)
        os.makedirs(client_dir, exist_ok=True)
        os.makedirs(os.path.join(client_dir, 'workflows'), exist_ok=True)
        
        # Generar docker-compose
        compose_data, admin_password, db_config, evolution_config = create_docker_compose(
            client_id, plan_config
        )
        
        # Guardar docker-compose.yml
        compose_path = os.path.join(client_dir, 'docker-compose.yml')
        with open(compose_path, 'w') as f:
            import yaml
            yaml.dump(compose_data, f, default_flow_style=False)
        
        # Iniciar servicios
        success, stdout, stderr = run_command(
            f'cd {client_dir} && docker-compose up -d',
            cwd=client_dir
        )
        
        if not success:
            return False, f"Error al iniciar contenedores: {stderr}"
        
        # Esperar a que n8n esté listo
        import time
        time.sleep(10)
        
        # Copiar workflows
        workflows_source = '/workflows'
        for workflow_path in plan_config['workflows']:
            source = os.path.join(workflows_source, workflow_path)
            if os.path.exists(source):
                import shutil
                dest = os.path.join(client_dir, 'workflows', os.path.basename(workflow_path))
                shutil.copy2(source, dest)
        
        # Crear instancia en BD
        instance = Instance(
            client_id=client_id,
            plan=plan,
            url=f'https://{client_id}.{BASE_DOMAIN}',
            company_name=company_name,
            contact_email=contact_email,
            admin_user=f'{client_id}_admin',
            admin_password=admin_password,
            status='active',
            use_postgres=plan_config.get('use_postgres', False),
            postgres_db=db_config['db_name'] if db_config else None,
            cpu_limit=plan_config['cpu'],
            memory_limit=plan_config['memory'],
            has_evolution=plan_config.get('deploy_evolution', False),
            evolution_url=evolution_config['url'] if evolution_config else None
        )
        
        db.session.add(instance)
        db.session.commit()
        
        # Guardar APIs si se proporcionaron
        if apis:
            for service, value in apis.items():
                cred = ApiCredential(
                    instance_id=instance.id,
                    service=service,
                    credential_data=value,
                    is_configured=True
                )
                db.session.add(cred)
            db.session.commit()
        
        return True, {
            'url': instance.url,
            'admin_user': instance.admin_user,
            'admin_password': admin_password,
            'evolution_url': evolution_config['url'] if evolution_config else None,
            'evolution_key': evolution_config['api_key'] if evolution_config else None
        }
        
    except Exception as e:
        return False, str(e)

# ================================================
# RUTAS WEB
# ================================================

@app.route('/')
def index():
    """Dashboard principal"""
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    
    instances = Instance.query.all()
    stats = {
        'total': len(instances),
        'active': len([i for i in instances if i.status == 'active']),
        'estandar': len([i for i in instances if i.plan == 'estandar']),
        'premium': len([i for i in instances if i.plan == 'premium']),
        'nexa': len([i for i in instances if i.plan == 'nexa'])
    }
    
    return render_template('dashboard.html', instances=instances, stats=stats, packs=PACK_CONFIG)

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username == os.getenv('PANEL_ADMIN_USER') and password == os.getenv('PANEL_ADMIN_PASSWORD'):
            session['logged_in'] = True
            session['username'] = username
            return redirect(url_for('index'))
        
        flash('Credenciales inválidas', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/instances/new', methods=['GET', 'POST'])
def new_instance():
    """Crear nueva instancia"""
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    
    if request.method == 'POST':
        data = request.form if request.form else request.get_json()
        
        client_id = data.get('client_id')
        plan = data.get('plan')
        company_name = data.get('company_name', '')
        contact_email = data.get('contact_email', '')
        
        # APIs opcionales
        apis = {}
        for api_key in ['openai_key', 'gmail_credentials', 'evolution_url', 
                       'evolution_key', 'airtable_pat', 'telegram_token']:
            if data.get(api_key):
                apis[api_key] = data[api_key]
        
        success, result = deploy_instance(client_id, plan, company_name, contact_email, apis)
        
        if success:
            if request.is_json:
                return jsonify({'success': True, 'data': result})
            flash(f'Instancia creada exitosamente: {result["url"]}', 'success')
            return redirect(url_for('index'))
        else:
            if request.is_json:
                return jsonify({'success': False, 'error': result}), 500
            flash(f'Error: {result}', 'error')
    
    return render_template('new_instance.html', packs=PACK_CONFIG)

@app.route('/instances/<int:instance_id>')
def instance_detail(instance_id):
    """Detalle de instancia"""
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    
    instance = Instance.query.get_or_404(instance_id)
    credentials = ApiCredential.query.filter_by(instance_id=instance_id).all()
    
    return render_template('instance_detail.html', 
                         instance=instance, 
                         credentials=credentials,
                         pack_config=PACK_CONFIG[instance.plan])

@app.route('/api/instances', methods=['GET'])
def api_list_instances():
    """API: Listar instancias"""
    instances = Instance.query.all()
    return jsonify([i.to_dict() for i in instances])

@app.route('/api/instances/<int:instance_id>/action/<action>', methods=['POST'])
def api_instance_action(instance_id, action):
    """API: Acción sobre instancia"""
    if 'logged_in' not in session:
        return jsonify({'error': 'No autorizado'}), 401
    
    instance = Instance.query.get_or_404(instance_id)
    client_dir = os.path.join(N8N_BASE_PATH, instance.client_id)
    
    actions_map = {
        'start': f'cd {client_dir} && docker-compose start',
        'stop': f'cd {client_dir} && docker-compose stop',
        'restart': f'cd {client_dir} && docker-compose restart',
        'delete': f'cd {client_dir} && docker-compose down -v'
    }
    
    if action not in actions_map:
        return jsonify({'error': 'Acción inválida'}), 400
    
    success, stdout, stderr = run_command(actions_map[action])
    
    if success:
        if action == 'delete':
            db.session.delete(instance)
        elif action == 'stop':
            instance.status = 'stopped'
        elif action == 'start':
            instance.status = 'active'
        
        db.session.commit()
        return jsonify({'success': True, 'action': action})
    
    return jsonify({'error': stderr}), 500

# ================================================
# INICIALIZACIÓN
# ================================================

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    
    app.run(host='0.0.0.0', port=5000, debug=False)
