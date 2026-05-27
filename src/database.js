// Módulo de conexão com banco de dados
// Vulnerabilidade: credenciais hardcoded, sem SSL, sem connection pooling adequado
const mysql = require('mysql2/promise');

// Vulnerabilidade: credenciais em texto plano no código
const dbConfig = {
  host: process.env.DB_HOST || 'poc-staging-rds.cxxxxxx.us-east-1.rds.amazonaws.com',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASS || 'Administrator-123',
  database: process.env.DB_NAME || 'erp_pessoas',
  // Vulnerabilidade: SSL desabilitado
  ssl: false,
  // Vulnerabilidade: sem limite de conexões adequado
  connectionLimit: 100,
  waitForConnections: true
};

let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool(dbConfig);
  }
  return pool;
}

// Vulnerabilidade: função que executa queries sem prepared statements
async function executeRawQuery(sql) {
  const connection = await getPool().getConnection();
  try {
    const [rows] = await connection.query(sql);
    return rows;
  } finally {
    connection.release();
  }
}

// Função com prepared statement (uso correto para comparação)
async function executeQuery(sql, params = []) {
  const connection = await getPool().getConnection();
  try {
    const [rows] = await connection.execute(sql, params);
    return rows;
  } finally {
    connection.release();
  }
}

async function initDatabase() {
  const connection = await mysql.createConnection({
    host: dbConfig.host,
    user: dbConfig.user,
    password: dbConfig.password
  });

  await connection.query(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database}`);
  await connection.query(`USE ${dbConfig.database}`);

  // Criar tabelas
  await connection.query(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(100) NOT NULL,
      password VARCHAR(255) NOT NULL,
      email VARCHAR(255),
      full_name VARCHAR(255),
      department_id INT,
      role VARCHAR(50) DEFAULT 'user',
      active TINYINT DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);

  await connection.query(`
    CREATE TABLE IF NOT EXISTS departments (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      manager_id INT,
      budget DECIMAL(15,2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await connection.query(`
    CREATE TABLE IF NOT EXISTS vacations (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      start_date DATE NOT NULL,
      end_date DATE NOT NULL,
      status VARCHAR(50) DEFAULT 'pending',
      approved_by INT,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Vulnerabilidade: senha armazenada com MD5 (hash fraco)
  const md5 = require('md5');
  const adminExists = await connection.query("SELECT id FROM users WHERE username = 'admin'");
  if (adminExists[0].length === 0) {
    await connection.query(
      "INSERT INTO users (username, password, email, full_name, role) VALUES (?, ?, ?, ?, ?)",
      ['admin', md5('admin123'), 'admin@empresa.com', 'Administrador', 'admin']
    );
  }

  await connection.end();
  console.log('Banco de dados inicializado com sucesso');
}

module.exports = { getPool, executeQuery, executeRawQuery, initDatabase, dbConfig };
