// server.js — Punto de entrada del backend
require('dotenv').config();
const express   = require('express');
const cors      = require('cors');
const sequelize = require('./config/database');

const clientesRouter  = require('./routes/clientes');
const serviciosRouter = require('./routes/servicios');
const turnosRouter    = require('./routes/turnos');

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(cors({
    origin:         process.env.CORS_ORIGIN,
    methods:        ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
    allowedHeaders: ['Content-Type','Authorization'],
    credentials:    true
}));

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        uptime: process.uptime(),
        env:    process.env.NODE_ENV
    });
});

app.use('/api/clientes',  clientesRouter);
app.use('/api/servicios', serviciosRouter);
app.use('/api/turnos',    turnosRouter);

app.use((req, res) => {
    res.status(404).json({ error: `Ruta ${req.method} ${req.path} no encontrada` });
});

app.use((err, req, res, next) => {
    console.error('[ERROR]', err.stack);
    res.status(500).json({ error: 'Error interno del servidor' });
});

(async () => {
    try {
        await sequelize.authenticate();
        console.log('✅ Conexión a RDS MySQL establecida correctamente');
        app.listen(PORT, '0.0.0.0', () => {
            console.log(`🚀 Backend escuchando en puerto ${PORT}`);
            console.log(`   CORS permitido desde: ${process.env.CORS_ORIGIN}`);
        });
    } catch (error) {
        console.error('❌ No se pudo conectar a la base de datos:', error);
        process.exit(1);
    }
})();