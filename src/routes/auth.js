// Rotas de autenticação
// Vulnerabilidades: SQL Injection, hash fraco (MD5), sem rate limiting, sem CSRF
const express = require('express');
const router = express.Router();
const md5 = require('md5');
const jwt = require('jsonwebtoken');
const { executeRawQuery, executeQuery } = require('../database');

// Vulnerabilidade: JWT secret hardcoded
const JWT_SECRET = 'jwt-secret-hardcoded-nao-faca-isso';

// Página de login
router.get('/login', (req, res) => {
  res.render('login', { error: null });
});

// Vulnerabilidade: SQL Injection - concatenação direta de input do usuário
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const hashedPassword = md5(password);

    // VULNERABILIDADE CRÍTICA: SQL Injection
    const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${hashedPassword}'`;
    const users = await executeRawQuery(query);

    if (users.length > 0) {
      req.session.user = users[0];
      // Vulnerabilidade: informações sensíveis no token
      const token = jwt.sign(
        { id: users[0].id, username: users[0].username, password: users[0].password },
        JWT_SECRET,
        { expiresIn: '24h' }
      );
      req.session.token = token;
      res.redirect('/users');
    } else {
      // Vulnerabilidade: mensagem de erro revela informação (user enumeration)
      res.render('login', { error: 'Usuário não encontrado ou senha incorreta' });
    }
  } catch (error) {
    // Vulnerabilidade: exposição de stack trace
    res.status(500).send(`Erro interno: ${error.message}\n${error.stack}`);
  }
});

// Vulnerabilidade: sem invalidação de sessão adequada
router.get('/logout', (req, res) => {
  req.session.destroy();
  res.redirect('/login');
});

// API de login (retorna JWT)
router.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const hashedPassword = md5(password);

    // Vulnerabilidade: SQL Injection na API também
    const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${hashedPassword}'`;
    const users = await executeRawQuery(query);

    if (users.length > 0) {
      const token = jwt.sign(
        { id: users[0].id, role: users[0].role },
        JWT_SECRET
      );
      // Vulnerabilidade: retorna dados sensíveis na resposta
      res.json({ token, user: users[0] });
    } else {
      res.status(401).json({ error: 'Credenciais inválidas' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message, stack: error.stack });
  }
});

module.exports = router;
