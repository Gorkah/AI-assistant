"""
NEXO IA - Inyector de Credenciales en Workflows
Modifica los workflows JSON para usar las credenciales configuradas
"""

import json
import os
import re

def inject_credentials_into_workflow(workflow_path, credentials):
    """
    Inyectar credenciales en un workflow de n8n
    
    Args:
        workflow_path: Ruta al archivo JSON del workflow
        credentials: Dict con las credenciales {service: value}
    
    Returns:
        bool: True si se modificó el archivo
    """
    try:
        with open(workflow_path, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
        
        modified = False
        
        # Recorrer todos los nodos del workflow
        if 'nodes' in workflow:
            for node in workflow['nodes']:
                node_type = node.get('type', '')
                
                # OpenAI nodes
                if 'openai' in node_type.lower():
                    if 'openai_key' in credentials and credentials['openai_key']:
                        if 'credentials' not in node:
                            node['credentials'] = {}
                        node['credentials']['openAiApi'] = {
                            'id': 'openai_credential',
                            'name': 'OpenAI API'
                        }
                        modified = True
                
                # Gmail nodes
                if 'gmail' in node_type.lower():
                    if 'gmail_credentials' in credentials and credentials['gmail_credentials']:
                        if 'credentials' not in node:
                            node['credentials'] = {}
                        node['credentials']['gmailOAuth2'] = {
                            'id': 'gmail_credential',
                            'name': 'Gmail OAuth2'
                        }
                        modified = True
                
                # Google Sheets nodes
                if 'googlesheets' in node_type.lower():
                    if 'gmail_credentials' in credentials and credentials['gmail_credentials']:
                        if 'credentials' not in node:
                            node['credentials'] = {}
                        node['credentials']['googleSheetsOAuth2Api'] = {
                            'id': 'google_sheets_credential',
                            'name': 'Google Sheets OAuth2'
                        }
                        modified = True
                
                # Airtable nodes
                if 'airtable' in node_type.lower():
                    if 'airtable_pat' in credentials and credentials['airtable_pat']:
                        if 'credentials' not in node:
                            node['credentials'] = {}
                        node['credentials']['airtableTokenApi'] = {
                            'id': 'airtable_credential',
                            'name': 'Airtable Personal Access Token'
                        }
                        modified = True
                
                # Telegram nodes
                if 'telegram' in node_type.lower():
                    if 'telegram_token' in credentials and credentials['telegram_token']:
                        if 'credentials' not in node:
                            node['credentials'] = {}
                        node['credentials']['telegramApi'] = {
                            'id': 'telegram_credential',
                            'name': 'Telegram Bot'
                        }
                        modified = True
                
                # HTTP Request nodes con Evolution API
                if node_type == 'n8n-nodes-base.httpRequest':
                    params = node.get('parameters', {})
                    url = params.get('url', '')
                    
                    if 'evolution' in url.lower() or params.get('name', '').lower().find('evolution') != -1:
                        if 'evolution_url' in credentials and credentials['evolution_url']:
                            # Reemplazar URL
                            if 'url' in params:
                                params['url'] = re.sub(
                                    r'https?://[^/]+',
                                    credentials['evolution_url'],
                                    params['url']
                                )
                                modified = True
                            
                            # Agregar header de autenticación
                            if 'evolution_key' in credentials and credentials['evolution_key']:
                                if 'headerParameters' not in params:
                                    params['headerParameters'] = {}
                                if 'parameters' not in params['headerParameters']:
                                    params['headerParameters']['parameters'] = []
                                
                                # Buscar si ya existe el header apikey
                                found = False
                                for header in params['headerParameters']['parameters']:
                                    if header.get('name', '').lower() == 'apikey':
                                        header['value'] = credentials['evolution_key']
                                        found = True
                                        break
                                
                                if not found:
                                    params['headerParameters']['parameters'].append({
                                        'name': 'apikey',
                                        'value': credentials['evolution_key']
                                    })
                                
                                modified = True
        
        # Guardar si hubo modificaciones
        if modified:
            with open(workflow_path, 'w', encoding='utf-8') as f:
                json.dump(workflow, f, indent=2, ensure_ascii=False)
            
            return True
        
        return False
        
    except Exception as e:
        print(f"Error procesando {workflow_path}: {e}")
        return False

def inject_credentials_in_directory(workflows_dir, credentials):
    """
    Inyectar credenciales en todos los workflows de un directorio
    
    Args:
        workflows_dir: Directorio con workflows JSON
        credentials: Dict con credenciales
    
    Returns:
        int: Número de workflows modificados
    """
    modified_count = 0
    
    for filename in os.listdir(workflows_dir):
        if filename.endswith('.json'):
            workflow_path = os.path.join(workflows_dir, filename)
            if inject_credentials_into_workflow(workflow_path, credentials):
                print(f"✓ Modificado: {filename}")
                modified_count += 1
            else:
                print(f"  Sin cambios: {filename}")
    
    return modified_count

def create_n8n_credentials_file(client_dir, credentials):
    """
    Crear archivo de credenciales de n8n
    Este archivo se importa en n8n para tener las credenciales disponibles
    """
    n8n_credentials = []
    
    # OpenAI
    if 'openai_key' in credentials and credentials['openai_key']:
        n8n_credentials.append({
            "id": "openai_credential",
            "name": "OpenAI API",
            "type": "openAiApi",
            "data": {
                "apiKey": credentials['openai_key']
            }
        })
    
    # Gmail OAuth2 (simplificado - en producción necesita flujo OAuth completo)
    if 'gmail_credentials' in credentials and credentials['gmail_credentials']:
        n8n_credentials.append({
            "id": "gmail_credential",
            "name": "Gmail OAuth2",
            "type": "gmailOAuth2",
            "data": {
                # Aquí iría la configuración OAuth real
                "oauthTokenData": credentials['gmail_credentials']
            }
        })
    
    # Airtable
    if 'airtable_pat' in credentials and credentials['airtable_pat']:
        n8n_credentials.append({
            "id": "airtable_credential",
            "name": "Airtable Personal Access Token",
            "type": "airtableTokenApi",
            "data": {
                "accessToken": credentials['airtable_pat']
            }
        })
    
    # Telegram
    if 'telegram_token' in credentials and credentials['telegram_token']:
        n8n_credentials.append({
            "id": "telegram_credential",
            "name": "Telegram Bot",
            "type": "telegramApi",
            "data": {
                "accessToken": credentials['telegram_token']
            }
        })
    
    # Guardar archivo de credenciales
    if n8n_credentials:
        credentials_file = os.path.join(client_dir, 'credentials.json')
        with open(credentials_file, 'w', encoding='utf-8') as f:
            json.dump(n8n_credentials, f, indent=2, ensure_ascii=False)
        
        return credentials_file
    
    return None

# Para testing
if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python workflow_injector.py <directorio_workflows>")
        sys.exit(1)
    
    workflows_dir = sys.argv[1]
    
    # Credenciales de ejemplo
    test_credentials = {
        'openai_key': 'sk-test123',
        'evolution_url': 'https://evolution.example.com',
        'evolution_key': 'test-api-key',
        'airtable_pat': 'pat-test',
        'telegram_token': '123456:ABC-DEF'
    }
    
    count = inject_credentials_in_directory(workflows_dir, test_credentials)
    print(f"\n✅ Total modificados: {count}")
