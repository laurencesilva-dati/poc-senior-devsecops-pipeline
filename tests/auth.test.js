// Testes unitários para rotas de autenticação
// Cobertura parcial proposital (~50%) para simular cenário real da Senior
const request = require('supertest');

// Mock do módulo database
jest.mock('../src/database', () => ({
  executeRawQuery: jest.fn(),
  executeQuery: jest.fn(),
  initDatabase: jest.fn()
}));

const app = require('../src/server');
const { executeRawQuery } = require('../src/database');

describe('Auth Routes', () => {
  describe('GET /login', () => {
    it('deve retornar a página de login', async () => {
      const res = await request(app).get('/login');
      expect(res.status).toBe(200);
      expect(res.text).toContain('ERP Gestão de Pessoas');
    });
  });

  describe('POST /login', () => {
    it('deve redirecionar para /users com credenciais válidas', async () => {
      executeRawQuery.mockResolvedValue([{ id: 1, username: 'admin', role: 'admin' }]);
      const res = await request(app)
        .post('/login')
        .send('username=admin&password=admin123');
      expect(res.status).toBe(302);
      expect(res.headers.location).toBe('/users');
    });

    it('deve mostrar erro com credenciais inválidas', async () => {
      executeRawQuery.mockResolvedValue([]);
      const res = await request(app)
        .post('/login')
        .send('username=invalido&password=errada');
      expect(res.status).toBe(200);
      expect(res.text).toContain('não encontrado');
    });
  });

  describe('GET /logout', () => {
    it('deve redirecionar para /login', async () => {
      const res = await request(app).get('/logout');
      expect(res.status).toBe(302);
      expect(res.headers.location).toBe('/login');
    });
  });
});
