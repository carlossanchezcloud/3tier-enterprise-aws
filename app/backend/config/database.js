// config/database.js
// Conexión a RDS MySQL usando variables de entorno
// El backend está en subred privada → accede a RDS por IP interna

require('dotenv').config();
const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
        host:    process.env.DB_HOST,
        port:    Number(process.env.DB_PORT) || 3306,
        dialect: 'mysql',

        pool: {
            max:     5,
            min:     0,
            acquire: 30000,
            idle:    10000
        },

        // SSL requerido en RDS MySQL — sin rejectUnauthorized estricto
        dialectOptions: process.env.NODE_ENV === 'production' ? {
            ssl: {
                require:            true,
                rejectUnauthorized: false
            }
        } : {},

        logging: process.env.NODE_ENV === 'development'
            ? (msg) => console.log('[SQL]', msg)
            : false
    }
);

module.exports = sequelize;