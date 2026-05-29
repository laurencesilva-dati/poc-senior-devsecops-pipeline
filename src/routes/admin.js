// Rotas administrativas - PROPOSITALMENTE VULNERÁVEIS
// Vulnerabilidades que o SonarQube detecta com certeza
const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// VULNERABILITY: Command Injection - input do usuario direto no exec
router.get('/ping', (req, res) => {
  const host = req.query.host;
  exec('ping -c 1 ' + host, (error, stdout) => {
    res.send(stdout || error.message);
  });
});

// VULNERABILITY: Path Traversal - input do usuario direto no readFile
router.get('/file', (req, res) => {
  const filename = req.query.name;
  const content = fs.readFileSync(filename, 'utf8');
  res.send(content);
});

// VULNERABILITY: Weak cryptography - MD5 e DES
router.post('/encrypt', (req, res) => {
  const data = req.body.data;
  // MD5 é considerado inseguro
  const hash = crypto.createHash('md5').update(data).digest('hex');
  // DES é considerado inseguro
  const cipher = crypto.createCipheriv('des-ecb', 'abcdefgh', '');
  let encrypted = cipher.update(data, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  res.json({ hash, encrypted });
});

// VULNERABILITY: Hardcoded password
const DB_PASSWORD = 'SuperSecret123!';
const API_KEY = 'sk-1234567890abcdef';
const AWS_SECRET = 'AKIAIOSFODNN7EXAMPLE';

// VULNERABILITY: SQL Injection direta (sem wrapper)
router.get('/search', (req, res) => {
  const mysql = require('mysql2/promise');
  const term = req.query.q;
  // Concatenação direta - SonarQube detecta isso
  const query = "SELECT * FROM users WHERE username = '" + term + "'";
  res.json({ query: query, message: 'Debug mode' });
});

// VULNERABILITY: Open redirect
router.get('/redirect', (req, res) => {
  const url = req.query.url;
  res.redirect(url);
});

// VULNERABILITY: Insecure random para tokens de segurança
router.get('/token', (req, res) => {
  // Math.random() não é criptograficamente seguro
  const token = Math.random().toString(36).substring(2);
  res.json({ token });
});

// VULNERABILITY: Regex DoS (ReDoS)
router.post('/validate-email', (req, res) => {
  const email = req.body.email;
  // Regex vulnerável a ReDoS
  const emailRegex = /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
  const isValid = emailRegex.test(email);
  res.json({ valid: isValid });
});

// VULNERABILITY: Prototype pollution
router.post('/config', (req, res) => {
  const config = {};
  const userInput = req.body;
  // Merge sem validação - prototype pollution
  for (const key in userInput) {
    config[key] = userInput[key];
  }
  res.json(config);
});

// VULNERABILITY: Information exposure via error messages
router.get('/debug', (req, res) => {
  try {
    throw new Error('Database connection failed: host=prod-db.internal password=admin123');
  } catch (e) {
    // Expõe stack trace e informações sensíveis
    res.status(500).json({
      error: e.message,
      stack: e.stack,
      env: process.env
    });
  }
});

// CODE SMELL: Código duplicado proposital
function processUserA(user) {
  if (user.name && user.name.length > 0) {
    const result = user.name.trim().toLowerCase();
    console.log('Processing user: ' + result);
    return { processed: true, name: result, timestamp: Date.now() };
  }
  return { processed: false, name: null, timestamp: Date.now() };
}

function processUserB(user) {
  if (user.name && user.name.length > 0) {
    const result = user.name.trim().toLowerCase();
    console.log('Processing user: ' + result);
    return { processed: true, name: result, timestamp: Date.now() };
  }
  return { processed: false, name: null, timestamp: Date.now() };
}

function processUserC(user) {
  if (user.name && user.name.length > 0) {
    const result = user.name.trim().toLowerCase();
    console.log('Processing user: ' + result);
    return { processed: true, name: result, timestamp: Date.now() };
  }
  return { processed: false, name: null, timestamp: Date.now() };
}

// BUG: Variável usada antes de ser definida
router.get('/report', (req, res) => {
  let data;
  if (req.query.type === 'full') {
    data = { type: 'full', items: [] };
  }
  // Bug: data pode ser undefined se type != 'full'
  res.json({ count: data.items.length });
});

module.exports = router;
