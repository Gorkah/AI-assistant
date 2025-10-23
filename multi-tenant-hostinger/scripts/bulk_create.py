#!/usr/bin/env python3
"""
NEXO IA - Script para Crear Múltiples Instancias en Lote
Uso: python bulk_create.py clientes.json
"""

import requests
import json
import sys
import time
from datetime import datetime

# Configuración
PANEL_URL = "https://panel.srv869945.hstgr.cloud"
# NOTA: En producción, usa autenticación adecuada

def create_instance(client_data):
    """Crear una instancia para un cliente"""
    print(f"\n{'='*60}")
    print(f"Creando instancia para: {client_data['client_id']}")
    print(f"{'='*60}")
    
    try:
        response = requests.post(
            f"{PANEL_URL}/instances/new",
            json=client_data,
            timeout=300  # 5 minutos timeout
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print(f"✅ ÉXITO: {result['data']['url']}")
                print(f"   Usuario: {result['data']['admin_user']}")
                print(f"   Password: {result['data']['admin_password']}")
                
                # Guardar credenciales
                with open('credenciales_generadas.txt', 'a') as f:
                    f.write(f"\n{'='*60}\n")
                    f.write(f"Cliente: {client_data['client_id']}\n")
                    f.write(f"Empresa: {client_data.get('company_name', 'N/A')}\n")
                    f.write(f"Plan: {client_data['plan']}\n")
                    f.write(f"URL: {result['data']['url']}\n")
                    f.write(f"Usuario: {result['data']['admin_user']}\n")
                    f.write(f"Password: {result['data']['admin_password']}\n")
                    f.write(f"Creado: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                
                return True, result['data']
            else:
                print(f"❌ ERROR: {result.get('error', 'Error desconocido')}")
                return False, result.get('error')
        else:
            print(f"❌ ERROR HTTP {response.status_code}: {response.text}")
            return False, response.text
            
    except requests.exceptions.Timeout:
        print("❌ TIMEOUT: La creación tardó más de 5 minutos")
        return False, "Timeout"
    except Exception as e:
        print(f"❌ EXCEPCIÓN: {str(e)}")
        return False, str(e)

def load_clients_from_json(filename):
    """Cargar lista de clientes desde JSON"""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data.get('clientes', [])
    except FileNotFoundError:
        print(f"❌ Archivo no encontrado: {filename}")
        return []
    except json.JSONDecodeError as e:
        print(f"❌ Error al parsear JSON: {e}")
        return []

def main():
    if len(sys.argv) < 2:
        print("Uso: python bulk_create.py clientes.json")
        print("\nFormato del archivo JSON:")
        print("""
{
  "clientes": [
    {
      "client_id": "empresa1",
      "plan": "premium",
      "company_name": "Empresa 1 SA",
      "contact_email": "contacto@empresa1.com",
      "contact_phone": "+34 666 111 111",
      "apis": {
        "openai_key": "sk-...",
        "evolution_url": "https://...",
        "evolution_key": "xxx",
        "airtable_pat": "pat..."
      }
    }
  ]
}
        """)
        sys.exit(1)
    
    filename = sys.argv[1]
    clientes = load_clients_from_json(filename)
    
    if not clientes:
        print("No se encontraron clientes para procesar")
        sys.exit(1)
    
    print(f"\n{'='*60}")
    print(f"   NEXO IA - Creación en Lote de Instancias")
    print(f"{'='*60}")
    print(f"Total de clientes a crear: {len(clientes)}")
    print(f"Panel: {PANEL_URL}")
    print(f"{'='*60}\n")
    
    # Confirmar
    respuesta = input("¿Continuar? (s/n): ")
    if respuesta.lower() != 's':
        print("Cancelado")
        sys.exit(0)
    
    # Limpiar archivo de credenciales
    with open('credenciales_generadas.txt', 'w') as f:
        f.write(f"CREDENCIALES GENERADAS - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Crear instancias
    resultados = {
        'exitosos': 0,
        'fallidos': 0,
        'detalles': []
    }
    
    for i, cliente in enumerate(clientes, 1):
        print(f"\n[{i}/{len(clientes)}] Procesando: {cliente['client_id']}")
        
        success, result = create_instance(cliente)
        
        if success:
            resultados['exitosos'] += 1
            resultados['detalles'].append({
                'client_id': cliente['client_id'],
                'status': 'success',
                'url': result['url']
            })
        else:
            resultados['fallidos'] += 1
            resultados['detalles'].append({
                'client_id': cliente['client_id'],
                'status': 'failed',
                'error': result
            })
        
        # Esperar entre creaciones para no sobrecargar
        if i < len(clientes):
            print(f"\nEsperando 30 segundos antes de crear la siguiente...")
            time.sleep(30)
    
    # Resumen final
    print(f"\n{'='*60}")
    print(f"   RESUMEN DE CREACIÓN")
    print(f"{'='*60}")
    print(f"✅ Exitosos: {resultados['exitosos']}")
    print(f"❌ Fallidos: {resultados['fallidos']}")
    print(f"\nCredenciales guardadas en: credenciales_generadas.txt")
    
    # Guardar resumen en JSON
    with open('resumen_creacion.json', 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'total': len(clientes),
            'exitosos': resultados['exitosos'],
            'fallidos': resultados['fallidos'],
            'detalles': resultados['detalles']
        }, f, indent=2)
    
    print(f"Resumen guardado en: resumen_creacion.json\n")

if __name__ == '__main__':
    main()
