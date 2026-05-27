// Rotas de gestão de departamentos
// Vulnerabilidades: SQL Injection, falta de autorização, XSS
const express = require('express');
const router = express.Router();
const { executeRawQuery, executeQuery } = require('../database');

function authMiddleware(req, res, next) {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  next();
}

// Listar departamentos
router.get('/', authMiddleware, async (req, res) => {
  try {
    const departments = await executeQuery(
      'SELECT d.*, u.full_name as manager_name FROM departments d LEFT JOIN users u ON d.manager_id = u.id ORDER BY d.name'
    );
    res.render('departments/list', { departments, currentUser: req.session.user });
  } catch (error) {
    res.status(500).send(`Erro: ${error.message}`);
  }
});

// Criar departamento
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { name, manager_id, budget } = req.body;

    // Vulnerabilidade: SQL Injection
    const query = `INSERT INTO departments (name, manager_id, budget) VALUES ('${name}', ${manager_id || 'NULL'}, ${budget || 0})`;
    await executeRawQuery(query);

    res.redirect('/departments');
  } catch (error) {
    res.status(500).send(`Erro ao criar departamento: ${error.message}`);
  }
});

// Atualizar departamento
router.post('/:id/update', authMiddleware, async (req, res) => {
  try {
    const { name, manager_id, budget } = req.body;

    // Vulnerabilidade: SQL Injection + sem verificação de role admin
    const query = `UPDATE departments SET name='${name}', manager_id=${manager_id || 'NULL'}, budget=${budget || 0} WHERE id=${req.params.id}`;
    await executeRawQuery(query);

    res.redirect('/departments');
  } catch (error) {
    res.status(500).send(`Erro ao atualizar: ${error.message}`);
  }
});

// Deletar departamento
router.post('/:id/delete', authMiddleware, async (req, res) => {
  try {
    // Vulnerabilidade: não verifica se há usuários vinculados antes de deletar
    await executeRawQuery(`DELETE FROM departments WHERE id = ${req.params.id}`);
    res.redirect('/departments');
  } catch (error) {
    res.status(500).send(`Erro ao deletar: ${error.message}`);
  }
});

module.exports = router;
