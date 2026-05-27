// Rotas de gestão de férias
// Vulnerabilidades: IDOR, SQL Injection, falta de validação de datas
const express = require('express');
const router = express.Router();
const { executeRawQuery, executeQuery } = require('../database');

function authMiddleware(req, res, next) {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  next();
}

// Listar férias
router.get('/', authMiddleware, async (req, res) => {
  try {
    const vacations = await executeQuery(
      `SELECT v.*, u.full_name as user_name, a.full_name as approver_name 
       FROM vacations v 
       LEFT JOIN users u ON v.user_id = u.id 
       LEFT JOIN users a ON v.approved_by = a.id 
       ORDER BY v.start_date DESC`
    );
    res.render('vacations/list', { vacations, currentUser: req.session.user });
  } catch (error) {
    res.status(500).send(`Erro: ${error.message}`);
  }
});

// Agendar férias
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { user_id, start_date, end_date, notes } = req.body;

    // Vulnerabilidade: sem validação de datas (data fim antes de data início)
    // Vulnerabilidade: sem verificação se o usuário já tem férias no período
    // Vulnerabilidade: SQL Injection
    const query = `INSERT INTO vacations (user_id, start_date, end_date, notes) 
                   VALUES (${user_id}, '${start_date}', '${end_date}', '${notes}')`;
    await executeRawQuery(query);

    res.redirect('/vacations');
  } catch (error) {
    res.status(500).send(`Erro ao agendar férias: ${error.message}`);
  }
});

// Aprovar férias
// Vulnerabilidade: qualquer usuário pode aprovar (sem verificação de role)
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    const vacationId = req.params.id;
    const approverId = req.session.user.id;

    // Vulnerabilidade: SQL Injection
    await executeRawQuery(`UPDATE vacations SET status='approved', approved_by=${approverId} WHERE id=${vacationId}`);
    res.redirect('/vacations');
  } catch (error) {
    res.status(500).send(`Erro ao aprovar: ${error.message}`);
  }
});

// Rejeitar férias
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    const vacationId = req.params.id;
    await executeRawQuery(`UPDATE vacations SET status='rejected' WHERE id=${vacationId}`);
    res.redirect('/vacations');
  } catch (error) {
    res.status(500).send(`Erro ao rejeitar: ${error.message}`);
  }
});

// Deletar solicitação de férias
// Vulnerabilidade: IDOR - qualquer usuário pode deletar qualquer solicitação
router.post('/:id/delete', authMiddleware, async (req, res) => {
  try {
    await executeRawQuery(`DELETE FROM vacations WHERE id = ${req.params.id}`);
    res.redirect('/vacations');
  } catch (error) {
    res.status(500).send(`Erro ao deletar: ${error.message}`);
  }
});

module.exports = router;
