// Rotas de gestão de usuários
// Vulnerabilidades: SQL Injection, XSS, IDOR, falta de autorização
const express = require('express');
const router = express.Router();
const md5 = require('md5');
const { executeRawQuery, executeQuery } = require('../database');

// Middleware de autenticação (vulnerável - não verifica role)
function authMiddleware(req, res, next) {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  next();
}

// Listar todos os usuários
router.get('/', authMiddleware, async (req, res) => {
  try {
    const users = await executeQuery('SELECT u.*, d.name as department_name FROM users u LEFT JOIN departments d ON u.department_id = d.id ORDER BY u.id');
    res.render('users/list', { users, currentUser: req.session.user });
  } catch (error) {
    res.status(500).send(`Erro: ${error.message}`);
  }
});

// Formulário de criação
router.get('/new', authMiddleware, (req, res) => {
  res.render('users/form', { user: null, error: null, currentUser: req.session.user });
});

// Criar usuário
// Vulnerabilidade: sem validação de input, XSS possível, senha fraca permitida
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { username, password, email, full_name, department_id, role } = req.body;

    // Vulnerabilidade: sem validação de email, sem sanitização
    // Vulnerabilidade: MD5 para hash de senha
    const hashedPassword = md5(password);

    // Vulnerabilidade: SQL Injection via concatenação
    const query = `INSERT INTO users (username, password, email, full_name, department_id, role) 
                   VALUES ('${username}', '${hashedPassword}', '${email}', '${full_name}', ${department_id || 'NULL'}, '${role || 'user'}')`;
    await executeRawQuery(query);

    res.redirect('/users');
  } catch (error) {
    res.render('users/form', { user: req.body, error: error.message, currentUser: req.session.user });
  }
});

// Ver detalhes do usuário
// Vulnerabilidade: IDOR - qualquer usuário autenticado pode ver qualquer outro
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    // Vulnerabilidade: SQL Injection no parâmetro id
    const query = `SELECT u.*, d.name as department_name FROM users u LEFT JOIN departments d ON u.department_id = d.id WHERE u.id = ${req.params.id}`;
    const users = await executeRawQuery(query);

    if (users.length === 0) {
      return res.status(404).send('Usuário não encontrado');
    }
    res.render('users/detail', { user: users[0], currentUser: req.session.user });
  } catch (error) {
    res.status(500).send(`Erro: ${error.message}`);
  }
});

// Atualizar usuário
// Vulnerabilidade: sem verificação de permissão (IDOR)
router.post('/:id/update', authMiddleware, async (req, res) => {
  try {
    const { username, email, full_name, department_id, role } = req.body;

    // Vulnerabilidade: SQL Injection
    const query = `UPDATE users SET username='${username}', email='${email}', full_name='${full_name}', department_id=${department_id || 'NULL'}, role='${role}' WHERE id=${req.params.id}`;
    await executeRawQuery(query);

    res.redirect('/users');
  } catch (error) {
    res.status(500).send(`Erro ao atualizar: ${error.message}`);
  }
});

// Deletar usuário
// Vulnerabilidade: sem confirmação, sem soft delete, IDOR
router.post('/:id/delete', authMiddleware, async (req, res) => {
  try {
    // Vulnerabilidade: SQL Injection + hard delete
    await executeRawQuery(`DELETE FROM users WHERE id = ${req.params.id}`);
    res.redirect('/users');
  } catch (error) {
    res.status(500).send(`Erro ao deletar: ${error.message}`);
  }
});

// API - buscar usuário por nome (vulnerável a SQL Injection)
router.get('/api/search', authMiddleware, async (req, res) => {
  try {
    const { name } = req.query;
    // Vulnerabilidade: SQL Injection via query parameter
    const query = `SELECT * FROM users WHERE full_name LIKE '%${name}%'`;
    const users = await executeRawQuery(query);
    res.json(users);
  } catch (error) {
    // Vulnerabilidade: exposição de detalhes internos
    res.status(500).json({ error: error.message, query: error.sql });
  }
});

module.exports = router;
