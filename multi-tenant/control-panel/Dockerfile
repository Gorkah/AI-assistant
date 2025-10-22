FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    docker.io \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar aplicación
COPY . .

# Crear directorios necesarios
RUN mkdir -p /app/instances /app/scripts

# Exponer puerto
EXPOSE 3000

# Comando de inicio
CMD ["python", "app.py"]
