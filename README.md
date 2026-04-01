$readme = @'
# 3tier-enterprise-aws

> Infraestructura AWS de alta disponibilidad para sistema de reservas de salón de belleza.
> Arquitectura de 3 capas con Terraform, CI/CD con GitHub Actions y acceso seguro vía SSM.

---

## Arquitectura
```
                         Internet
                             │
                    ┌────────▼────────┐
                    │   Application   │
                    │  Load Balancer  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
    ┌─────────▼─────────┐       ┌──────────▼──────────┐
    │   EC2 Backend     │       │   EC2 Backend        │
    │      AZ1          │       │      AZ2             │
    │  Node.js + PM2    │       │  Node.js + PM2       │
    └─────────┬─────────┘       └──────────┬───────────┘
              └──────────────┬──────────────┘
                             │
                    ┌────────▼────────┐
                    │   RDS MySQL 8.0 │
                    └─────────────────┘
```

---

## Principios de seguridad

| Capa | Control |
|------|---------|
| Red | EC2 y RDS sin IP pública |
| Acceso EC2 | SSM Session Manager — sin llaves SSH |
| Security Groups | Reglas por referencia a SG, mínimo privilegio |
| RDS | SSL en tránsito + cifrado en reposo |
| CI/CD | OIDC — sin access keys hardcodeadas |
| Estado Terraform | S3 cifrado + DynamoDB lock |

---

## Estructura del repositorio
```
3tier-enterprise-aws/
├── terraform/
│   ├── modules/
│   │   ├── networking/
│   │   ├── compute/
│   │   └── database/
│   └── environments/prod/
├── app/
│   └── backend/
├── database/
│   └── schema.sql
├── scripts/
│   ├── user_data.sh
│   └── validate_infra.sh
└── .github/
    └── workflows/
        ├── infra.yml
        └── app.yml
```

---

## Stack tecnológico

| Componente | Tecnología |
|------------|-----------|
| Runtime | Node.js 20 LTS |
| Framework | Express 4 |
| ORM | Sequelize 6 + mysql2 |
| Base de datos | RDS MySQL 8.0 |
| Infraestructura | Terraform |
| CI/CD | GitHub Actions |
| Acceso EC2 | AWS Systems Manager (SSM) |

---

## API Reference

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/health` | Health check para ALB |
| GET | `/api/clientes` | Listar clientes |
| POST | `/api/clientes` | Crear cliente |
| PUT | `/api/clientes/:id` | Actualizar cliente |
| DELETE | `/api/clientes/:id` | Eliminar cliente |
| GET | `/api/servicios` | Listar servicios activos |
| POST | `/api/servicios` | Crear servicio |
| PUT | `/api/servicios/:id` | Actualizar servicio |
| GET | `/api/turnos` | Listar turnos |
| POST | `/api/turnos` | Crear turno |
| PATCH | `/api/turnos/:id/estado` | Cambiar estado |
| DELETE | `/api/turnos/:id` | Eliminar turno |

---

## CI/CD

### infra.yml
Se dispara en cada Pull Request con cambios en `terraform/**`
```
terraform fmt → tflint → tfsec → terraform validate
```

### app.yml
Se dispara en cada push a main con cambios en `app/backend/**`
```
Auth OIDC → SSM Send Command → git pull + npm install + pm2 restart
```

---

## Desarrollo local
```bash
cd app/backend
cp .env.example .env
# Completar .env con credenciales locales
npm install
npm run dev
```

---

## Estado del proyecto

- [x] Backend Node.js + MySQL migrado y validado
- [x] Schema MySQL con tablas, índices y seed
- [ ] Módulo Terraform networking
- [ ] Módulo Terraform compute
- [ ] Módulo Terraform database
- [ ] Workflows GitHub Actions

---

## Autor

**Carlos Sánchez** — [@carlossanchezcloud](https://github.com/carlossanchezcloud)
'@
$readme | Out-File -FilePath README.md -Encoding utf8

git add README.md
git commit -m "docs: clean README remove sensitive info"
git pushe