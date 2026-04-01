#!/bin/bash
# ==============================================================================
# user_data_website.sh — Bootstrap EC2 Website (Nginx + React/Vite build)
# Variables inyectadas via templatefile() desde Terraform:
#   repo_url    — URL HTTPS del repositorio GitHub
#   backend_alb — DNS del ALB interno (Node.js API)
# ==============================================================================

set -euo pipefail
exec > /var/log/user_data_website.log 2>&1

echo "[$(date)] Iniciando bootstrap Website..."

# ------------------------------------------------------------------------------
# 1. Sistema actualizado
# ------------------------------------------------------------------------------
dnf update -y

# ------------------------------------------------------------------------------
# 2. Node.js 20 via NodeSource + Git
# ------------------------------------------------------------------------------
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs git

node --version
npm --version

# ------------------------------------------------------------------------------
# 3. Nginx
# ------------------------------------------------------------------------------
dnf install -y nginx

# ------------------------------------------------------------------------------
# 4. Clonar repositorio
# ------------------------------------------------------------------------------
git clone ${repo_url} /app

# ------------------------------------------------------------------------------
# 5. Build React/Vite
# ------------------------------------------------------------------------------
cd /app/app/frontend
npm install
npm run build

# ------------------------------------------------------------------------------
# 6. Copiar build a raiz de Nginx
# ------------------------------------------------------------------------------
cp -r dist/* /usr/share/nginx/html/

# ------------------------------------------------------------------------------
# 7. Configuracion Nginx — SPA + proxy /api/ hacia ALB interno
# ------------------------------------------------------------------------------
cat > /etc/nginx/conf.d/salon.conf <<'NGINXCONF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Health check para el ALB publico
    location /health {
        access_log off;
        return 200 '{"status":"ok"}';
        add_header Content-Type application/json;
    }

    # Proxy hacia API Backend via ALB interno
    location /api/ {
        proxy_pass http://${backend_alb}:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }

    # SPA fallback — todas las rutas a index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINXCONF

# Deshabilitar config por defecto si existe
rm -f /etc/nginx/conf.d/default.conf

# ------------------------------------------------------------------------------
# 8. Arrancar Nginx
# ------------------------------------------------------------------------------
systemctl enable nginx
systemctl start nginx

echo "[$(date)] Bootstrap Website completado."
