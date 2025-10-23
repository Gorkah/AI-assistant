# ✅ Checklist de Instalación y Configuración

## 📋 Pre-Instalación (En tu PC)

- [ ] Tienes acceso SSH al VPS: `ssh root@srv869945.hstgr.cloud`
- [ ] Traefik está corriendo en el VPS
- [ ] Red Docker `root_default` existe
- [ ] Dominio `srv869945.hstgr.cloud` está configurado
- [ ] Tienes los workflows en carpetas (Recepcionista/, LEADS/, etc.)

---

## 🚀 Instalación (En el VPS)

### Paso 1: Preparar el entorno
```bash
- [ ] ssh root@srv869945.hstgr.cloud
- [ ] cd /srv
- [ ] git clone https://github.com/tu-usuario/AI-assistant.git
- [ ] cd AI-assistant/multi-tenant-hostinger
```

### Paso 2: Verificar Traefik
```bash
- [ ] docker ps | grep traefik
      # Debe aparecer un contenedor traefik corriendo

- [ ] docker network ls | grep root_default
      # Debe existir la red root_default
```

### Paso 3: Ejecutar instalación
```bash
- [ ] chmod +x install.sh
- [ ] ./install.sh
- [ ] Guardar contraseña del panel que aparece al final
- [ ] Verificar que no hubo errores
```

### Paso 4: Verificar instalación
```bash
- [ ] docker ps | grep nexo
      # Deberías ver: nexo_postgres, nexo_redis, nexo_panel

- [ ] curl http://localhost:5000
      # Debe responder (aunque sea con redirect)

- [ ] docker logs nexo_panel
      # Ver que no hay errores críticos
```

---

## 🌐 Configuración DNS (Si no está hecha)

- [ ] Acceder a panel de control de dominio
- [ ] Crear registro A: `panel.srv869945.hstgr.cloud` → IP del VPS
- [ ] Esperar propagación DNS (usar `nslookup panel.srv869945.hstgr.cloud`)

---

## 🎨 Primera Prueba - Panel de Control

### Acceso al Panel
```
- [ ] Abrir: https://panel.srv869945.hstgr.cloud
- [ ] Login con:
      Usuario: admin
      Password: [la que guardaste en Paso 3]
- [ ] Dashboard debe mostrar 0 instancias
```

---

## 🎯 Crear Primera Instancia de Prueba

### Desde el Panel Web
```
- [ ] Click en "+ Nueva Instancia"
- [ ] Llenar formulario:
      - Cliente ID: test-demo
      - Empresa: Test Demo SA
      - Email: test@demo.com
      - Plan: Estándar
- [ ] Click "Crear Instancia"
- [ ] Esperar 1-2 minutos
- [ ] GUARDAR credenciales que aparecen
```

### Verificar la Instancia
```bash
- [ ] docker ps | grep n8n_test-demo
      # Debe aparecer el contenedor

- [ ] docker logs n8n_test-demo
      # Ver que n8n arrancó correctamente

- [ ] curl https://test-demo.srv869945.hstgr.cloud
      # Debe responder (aunque pida autenticación)
```

### Acceder a n8n
```
- [ ] Abrir: https://test-demo.srv869945.hstgr.cloud
- [ ] Login con las credenciales guardadas
- [ ] Verificar que cargó la interfaz de n8n
- [ ] Ver que hay workflows importados
```

---

## 🔧 Configuración Opcional

### Copiar workflows si están en otro directorio
```bash
- [ ] cd /srv/AI-assistant
- [ ] ls Recepcionista/  # Verificar que existen
- [ ] cp -r Recepcionista/ LEADS/ ICEBREAKER/ multi-tenant-hostinger/workflows/
```

### Configurar backups automáticos
```bash
- [ ] crontab -e
- [ ] Agregar línea:
      0 2 * * * cd /srv/n8n && tar -czf backup_$(date +\%Y\%m\%d).tar.gz */
```

### Configurar monitoreo externo
```
- [ ] Registrarse en UptimeRobot (gratis)
- [ ] Agregar monitor para: https://panel.srv869945.hstgr.cloud
- [ ] Agregar monitor para cada instancia de cliente
```

---

## ✅ Verificación Final

### Sistema Base
```bash
- [ ] docker-compose -f docker-compose.panel.yml ps
      # Todos los servicios deben estar "Up"

- [ ] df -h
      # Verificar que hay espacio suficiente

- [ ] free -h
      # Verificar memoria disponible
```

### Panel Funcionando
```
- [ ] Panel carga correctamente
- [ ] Puedes crear instancias
- [ ] Las instancias se ven en el dashboard
- [ ] Puedes acceder a cada instancia creada
```

### SSL Funcionando
```bash
- [ ] curl -I https://panel.srv869945.hstgr.cloud
      # Debe retornar 200 o 302, no error de certificado

- [ ] curl -I https://test-demo.srv869945.hstgr.cloud
      # Igual, SSL debe funcionar
```

---

## 🎓 Próximos Pasos

Ahora que todo funciona:

### 1. Crear Instancia para Cliente Real
- [ ] Decidir el plan (Estándar/Premium/NEXA)
- [ ] Crear instancia desde panel
- [ ] Configurar APIs del cliente
- [ ] Entregar credenciales al cliente

### 2. Documentar para tu Equipo
- [ ] Guardar credenciales en gestor de contraseñas
- [ ] Documentar procedimiento de creación
- [ ] Crear lista de clientes activos

### 3. Configurar Mantenimiento
- [ ] Script de backup automático
- [ ] Monitoreo de recursos
- [ ] Alertas de caídas
- [ ] Plan de escalabilidad

---

## 🆘 Si Algo Falla

### Panel no carga
```bash
docker-compose -f docker-compose.panel.yml logs panel_control
docker-compose -f docker-compose.panel.yml restart
```

### Instancia no se crea
```bash
docker-compose -f docker-compose.panel.yml logs -f panel_control
# Ver el error específico
```

### SSL no funciona
```bash
docker logs traefik 2>&1 | grep ERROR
# Verificar configuración de Traefik
```

### Sin espacio en disco
```bash
docker system prune -a  # Limpiar imágenes no usadas
du -sh /srv/n8n/*       # Ver qué ocupa más
```

---

## 📞 Soporte

Si necesitas ayuda:
1. Revisa los logs: `docker-compose -f docker-compose.panel.yml logs`
2. Consulta README.md y GUIA_RAPIDA.md
3. Busca el error específico en la documentación

---

**¡Checklist completado! Tu sistema multi-tenant está operativo. 🎉**

**Siguiente:** [Crear tu primer cliente real](GUIA_RAPIDA.md#-crear-tu-primer-cliente)
