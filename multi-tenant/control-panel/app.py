# ================================================
# NEXO IA - Panel de Control Multi-Tenant
# ================================================

from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import subprocess
import json
import os
import secrets

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', secrets.token_hex(32))
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# ================================================
# MODELOS DE BASE DE DATOS
# ================================================

class Instance(db.Model):
    __tablename__ = 'instances'
    
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.String(100), unique=True, nullable=False)
    plan = db.Column(db.String(20), nullable=False)  # estandar, premium, nexa
    url = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(20), default='active')  # active, suspended, deleted
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Metadata
    company_name = db.Column(db.String(255))
    contact_email = db.Column(db.String(255))
    contact_phone = db.Column(db.String(50))
    
    # Recursos
    cpu_limit = db.Column(db.Float, default=1.0)
    memory_limit = db.Column(db.String(10), default='2g')
    
    # APIs configuradas
    apis_configured = db.Column(db.JSON, default={})
    
    def to_dict(self):
        return {
            'id': self.id,
            'client_id': self.client_id,
            'plan': self.plan,
            'url': self.url,
            'status': self.status,
            'created_at': self.created_at.isoformat(),
            'company_name': self.company_name,
            'contact_email': self.contact_email
        }

class ApiKey(db.Model):
    __tablename__ = 'api_keys'
    
    id = db.Column(db.Integer, primary_key=True)
    instance_id = db.Column(db.Integer, db.ForeignKey('instances.id'), nullable=False)
    service = db.Column(db.String(50), nullable=False)  # openai, evolution, airtable, etc
    key_value = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    instance = db.relationship('Instance', backref=db.backref('api_keys', lazy=True))

class Usage(db.Model):
    __tablename__ = 'usage'
    
    id = db.Column(db.Integer, primary_key=True)
    instance_id = db.Column(db.Integer, db.ForeignKey('instances.id'), nullable=False)
    date = db.Column(db.Date, nullable=False)
    workflows_executed = db.Column(db.Integer, default=0)
    api_calls = db.Column(db.Integer, default=0)
    storage_mb = db.Column(db.Float, default=0)
    
    instance = db.relationship('Instance', backref=db.backref('usage_records', lazy=True))

# ================================================
# UTILIDADES
# ================================================

def run_provision_script(client_id, plan, config_json="{}"):
    """Ejecutar script de aprovisionamiento"""
    script_path = '/app/scripts/provision_instance.sh'
    try:
        result = subprocess.run(
            [script_path, client_id, plan, config_json],
            capture_output=True,
            text=True,
            timeout=300
        )
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def get_docker_stats(container_name):
    """Obtener estadísticas de Docker"""
    try:
        result = subprocess.run(
            ['docker', 'stats', container_name, '--no-stream', '--format', 
             '{"cpu":"{{.CPUPerc}}","memory":"{{.MemUsage}}"}'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return json.loads(result.stdout.strip())
    except:
        pass
    return {"cpu": "N/A", "memory": "N/A"}

# ================================================
# RUTAS DEL PANEL
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
    
    return render_template('dashboard.html', instances=instances, stats=stats)

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login al panel"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        admin_user = os.getenv('PANEL_ADMIN_USER', 'admin')
        admin_pass = os.getenv('PANEL_ADMIN_PASSWORD')
        
        if username == admin_user and password == admin_pass:
            session['logged_in'] = True
            return redirect(url_for('index'))
        
        return render_template('login.html', error='Credenciales inválidas')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/instances/new', methods=['GET', 'POST'])
def new_instance():
    """Crear nueva instancia"""
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    
    if request.method == 'POST':
        data = request.get_json()
        
        client_id = data.get('client_id')
        plan = data.get('plan')
        company_name = data.get('company_name')
        contact_email = data.get('contact_email')
        
        # Validaciones
        if not client_id or not plan:
            return jsonify({'success': False, 'error': 'Datos incompletos'}), 400
        
        if Instance.query.filter_by(client_id=client_id).first():
            return jsonify({'success': False, 'error': 'Cliente ya existe'}), 400
        
        # Config JSON para APIs si se proporcionan
        config_json = {}
        if data.get('openai_key'):
            config_json['OPENAI_API_KEY'] = data['openai_key']
        if data.get('evolution_url'):
            config_json['EVOLUTION_API_URL'] = data['evolution_url']
        if data.get('evolution_key'):
            config_json['EVOLUTION_API_KEY'] = data['evolution_key']
        if data.get('airtable_pat'):
            config_json['AIRTABLE_PAT'] = data['airtable_pat']
        
        # Ejecutar aprovisionamiento
        success, output = run_provision_script(
            client_id, 
            plan, 
            json.dumps(config_json)
        )
        
        if success:
            base_domain = os.getenv('BASE_DOMAIN')
            # La instancia ya debería estar creada por el script
            # Solo actualizamos la info adicional
            instance = Instance.query.filter_by(client_id=client_id).first()
            if instance:
                instance.company_name = company_name
                instance.contact_email = contact_email
                db.session.commit()
            
            return jsonify({
                'success': True, 
                'url': f'https://{client_id}.{base_domain}',
                'output': output
            })
        else:
            return jsonify({'success': False, 'error': output}), 500
    
    return render_template('new_instance.html')

@app.route('/instances/<int:instance_id>')
def instance_detail(instance_id):
    """Detalle de instancia"""
    if 'logged_in' not in session:
        return redirect(url_for('login'))
    
    instance = Instance.query.get_or_404(instance_id)
    container_name = f"n8n_{instance.client_id}"
    stats = get_docker_stats(container_name)
    
    return render_template('instance_detail.html', instance=instance, stats=stats)

@app.route('/api/instances/<int:instance_id>/status')
def instance_status(instance_id):
    """Estado de la instancia"""
    instance = Instance.query.get_or_404(instance_id)
    container_name = f"n8n_{instance.client_id}"
    
    try:
        result = subprocess.run(
            ['docker', 'inspect', '-f', '{{.State.Status}}', container_name],
            capture_output=True,
            text=True
        )
        docker_status = result.stdout.strip()
        
        return jsonify({
            'status': docker_status,
            'url': instance.url,
            'plan': instance.plan
        })
    except:
        return jsonify({'status': 'unknown'}), 500

@app.route('/api/instances/<int:instance_id>/action/<action>', methods=['POST'])
def instance_action(instance_id, action):
    """Acciones sobre instancia"""
    if 'logged_in' not in session:
        return jsonify({'error': 'No autorizado'}), 401
    
    instance = Instance.query.get_or_404(instance_id)
    container_name = f"n8n_{instance.client_id}"
    
    actions_map = {
        'start': ['docker', 'start', container_name],
        'stop': ['docker', 'stop', container_name],
        'restart': ['docker', 'restart', container_name]
    }
    
    if action not in actions_map:
        return jsonify({'error': 'Acción inválida'}), 400
    
    try:
        subprocess.run(actions_map[action], check=True)
        
        if action == 'stop':
            instance.status = 'suspended'
        elif action == 'start':
            instance.status = 'active'
        
        db.session.commit()
        
        return jsonify({'success': True, 'action': action})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/instances', methods=['GET'])
def list_instances():
    """API: Listar instancias"""
    instances = Instance.query.all()
    return jsonify([i.to_dict() for i in instances])

# ================================================
# INICIALIZACIÓN
# ================================================

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=3000, debug=False)
