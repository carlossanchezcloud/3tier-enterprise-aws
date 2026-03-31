# Salón de Belleza — Sistema de Reservas
## Arquitectura AWS de 3 Capas Segura

```
Internet → ALB → EC2 Frontend (React/Vite) [Subred Pública]
                       ↓ Axios (IP privada)
              EC2 Backend (Node/Express)     [Subred Privada App]
                       ↓ Sequelize
              RDS PostgreSQL                 [Subred Privada Datos]
```

---

## Estructura del proyecto

```
salon-belleza/
├── database/
│   └── schema.sql              # DDL: tablas, índices, triggers, seed
├── backend/
│   ├── server.js               # Entry point Express
│   ├── .env.example            # Variables de entorno (copiar a .env)
│   ├── config/database.js      # Sequelize + SSL para RDS
│   ├── models/
│   │   ├── Cliente.js
│   │   ├── Servicio.js
│   │   └── Turno.js            # Asociaciones FK + ENUM estado
│   └── routes/
│       ├── clientes.js         # CRUD + validación
│       ├── servicios.js        # CRUD + filtro activos
│       └── turnos.js           # CRUD + detección de conflicto de horario
├── frontend/
│   ├── vite.config.js
│   ├── index.html
│   ├── .env.example            # VITE_API_URL → IP privada del backend
│   └── src/
│       ├── main.jsx
│       ├── App.jsx             # Router con 3 secciones
│       ├── index.css           # Diseño dark luxury
│       ├── services/api.js     # Axios centralizado
│       └── pages/
│           ├── Turnos.jsx      # Agenda + filtro + cambio de estado
│           ├── Clientes.jsx    # Grid de tarjetas + búsqueda
│           └── Servicios.jsx   # Grid + toggle activo/inactivo
└── infra/
    ├── deploy.sh               # Guía completa AWS CLI paso a paso
    ├── nginx-frontend.conf     # Nginx para servir el build de Vite
    └── salon-backend.service   # Systemd para Node.js
```

---

## Inicio rápido (desarrollo local)

### Backend
```bash
cd backend
cp .env.example .env
# Editar .env con tus credenciales de PostgreSQL local
npm install
node server.js
```

### Frontend
```bash
cd frontend
cp .env.example .env
# VITE_API_URL=http://localhost:3001/api
npm install
npm run dev
```

### Base de datos local
```bash
psql -U postgres -c "CREATE DATABASE salon_db;"
psql -U postgres -d salon_db -f database/schema.sql
```

---

## API Reference

| Método | Ruta                          | Descripción                          |
|--------|-------------------------------|--------------------------------------|
| GET    | /api/clientes                 | Listar todos los clientes            |
| POST   | /api/clientes                 | Crear cliente                        |
| PUT    | /api/clientes/:id             | Actualizar cliente                   |
| DELETE | /api/clientes/:id             | Eliminar cliente (cascade turnos)    |
| GET    | /api/servicios                | Listar servicios activos             |
| POST   | /api/servicios                | Crear servicio                       |
| PUT    | /api/servicios/:id            | Actualizar / desactivar servicio     |
| GET    | /api/turnos?fecha=YYYY-MM-DD  | Listar turnos (opcional: por fecha)  |
| POST   | /api/turnos                   | Crear turno (valida conflicto)       |
| PATCH  | /api/turnos/:id/estado        | Cambiar estado del turno             |
| DELETE | /api/turnos/:id               | Eliminar turno                       |
| GET    | /health                       | Health check (para ALB)              |

---

## Seguridad implementada

- **Red**: RDS y backend sin IP pública. Solo el frontend/ALB tiene acceso a Internet.
- **Security Groups**: Reglas por referencia a SG (no por IP), siguiendo mínimo privilegio.
- **CORS**: El backend solo acepta peticiones del origen exacto del frontend.
- **SSL en RDS**: Conexión cifrada en tránsito (`ssl: { require: true }`).
- **Cifrado en reposo**: `--storage-encrypted` en el comando de creación RDS.
- **Validación**: `express-validator` en todas las rutas antes de tocar la BD.
- **Protección BD**: `--deletion-protection` en RDS para evitar borrado accidental.
