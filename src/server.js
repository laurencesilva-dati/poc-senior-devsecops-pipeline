// POC ERP Gestão de Pessoas - Servidor Principal
// ATENÇÃO: Esta aplicação contém vulnerabilidades PROPOSITAIS para testes de DevSecOps
const express = require('express');
const bodyParser = require('body-parser');
const session = require('express-session');
const path = require('path');
const app = express();

// Vulnerabilidade: credenciais hardcoded
const DB_HOST = process.env.DB_HOST || 'poc-staging-rds.cxxxxxx.us-east-1.rds.amazonaws.com';
const DB_USER = process.env.DB_USER || 'admin';
const DB_PASS = process.env.DB_PASS || 'Administrator-123';
const DB_NAME = process.env.DB_NAME || 'erp_pessoas';
const SECRET_KEY = 'minha-chave-secreta-super-insegura-123';
const JWT_SECRET = 'jwt-secret-hardcoded-nao-faca-isso';

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// Vulnerabilidade: session secret hardcoded e configuração insegura
app.use(session({
  secret: SECRET_KEY,
  resave: false,
  saveUninitialized: true,
  cookie: { secure: false }
}));

// Importar rotas
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const departmentRoutes = require('./routes/departments');
const vacationRoutes = require('./routes/vacations');

app.use('/', authRoutes);
app.use('/users', userRoutes);
app.use('/departments', departmentRoutes);
app.use('/vacations', vacationRoutes);

// Rota principal
app.get('/', (req, res) => {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  res.redirect('/users');
});

const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`ERP Gestão de Pessoas rodando na porta ${PORT}`);
  });
}

module.exports = app;
