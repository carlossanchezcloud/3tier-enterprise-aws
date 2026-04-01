#!/bin/bash
# ==============================================================================
# user_data_backend.sh — Bootstrap EC2 Backend (Node.js API + PM2)
# Variables inyectadas via templatefile() desde Terraform:
#   repo_url    — URL HTTPS del repositorio GitHub
#   db_host     — Hostname RDS (sin puerto)
#   db_port     — Puerto MySQL (3306)
#   db_name     — Nombre base de datos
#   db_user     — Usuario master RDS
#   db_password — Password master RDS
#   cors_origin — DNS del ALB publico
#   node_env    — Entorno Node.js (production)
# ==============================================================================

set -euo pipefail
exec > /var/log/user_data_backend.log 2>&1

echo "[$(date)] Iniciando bootstrap Backend..."

# ------------------------------------------------------------------------------
# 1. Sistema actualizado
# ------------------------------------------------------------------------------
dnf update -y

# ------------------------------------------------------------------------------
# 2. Node.js 20 via NodeSource + Git + cliente MySQL
# ------------------------------------------------------------------------------
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs git mysql

node --version
npm --version

# ------------------------------------------------------------------------------
# 3. PM2 — gestor de procesos para Node.js en produccion
# ------------------------------------------------------------------------------
npm install -g pm2

# ------------------------------------------------------------------------------
# 4. Clonar repositorio
# ------------------------------------------------------------------------------
git clone ${repo_url} /app

# ------------------------------------------------------------------------------
# 5. Generar archivo .env con variables de entorno
#    Las credenciales se inyectan desde Terraform — nunca en el repo
# ------------------------------------------------------------------------------
cat > /app/app/backend/.env <<ENVFILE
NODE_ENV=${node_env}
PORT=3001
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
CORS_ORIGIN=http://${cors_origin}
ENVFILE

# Proteger el archivo .env (solo root puede leerlo)
chmod 600 /app/app/backend/.env

# ------------------------------------------------------------------------------
# 6. Instalar dependencias de produccion
# ------------------------------------------------------------------------------
cd /app/app/backend
npm install --production

# ------------------------------------------------------------------------------
# 7. Aplicar schema SQL solo si la tabla principal no existe
#    Evita re-ejecutar DDL en reinicios del ASG
# ------------------------------------------------------------------------------
TABLE_EXISTS=$(mysql -h ${db_host} -P ${db_port} -u ${db_user} -p${db_password} \
  ${db_name} --silent --skip-column-names \
  -e "SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema='${db_name}' AND table_name='clientes';" 2>/dev/null || echo "0")

if [ "$TABLE_EXISTS" = "0" ]; then
  echo "[$(date)] Aplicando schema.sql..."
  mysql -h ${db_host} -P ${db_port} -u ${db_user} -p${db_password} \
    ${db_name} < /app/database/schema.sql
  echo "[$(date)] Schema aplicado."
else
  echo "[$(date)] Tabla clientes ya existe — omitiendo schema.sql."
fi

# ------------------------------------------------------------------------------
# 8. Arrancar aplicacion con PM2
# ------------------------------------------------------------------------------
pm2 start /app/app/backend/server.js --name backend

# Persistir PM2 entre reinicios del sistema
pm2 startup systemd -u root --hp /root
pm2 save

echo "[$(date)] Bootstrap Backend completado."
