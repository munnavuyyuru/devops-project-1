const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

//const DB_PASSWORD = fs.readFileSync('/run/secrets/db_password', 'utf8').trim();
//const JWT_SECRET = fs.readFileSync('/run/secrets/jwt_secret', 'utf8').trim();

function loadSecret(secretName, envVar) {
  if (process.env[envVar]) {
    return process.env[envVar].trim();
  }

  const prodPath = path.join('/run/secrets', secretName);
  if (fs.existsSync(prodPath)) {
    return fs.readFileSync(prodPath, 'utf8').trim();
  }

  const devPath = path.join(__dirname, '..', 'secrets', `${secretName}.txt`);
  if (fs.existsSync(devPath)) {
    return fs.readFileSync(devPath, 'utf8').trim();
  }

  throw new Error(`Secret ${secretName} not found in env, ${prodPath}, or ${devPath}`);
}

const DB_PASSWORD = loadSecret('db_password', 'DB_PASSWORD');
const JWT_SECRET = loadSecret('jwt_secret', 'JWT_SECRET');

console.log('Secrets loaded successfully');

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'todoapp',
  user: process.env.DB_USER || 'todouser',
  password: DB_PASSWORD
});

// Health check endpoint (CRITICAL for production)
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString(),
      secrets: 'loaded'
    });
  } catch (err) {
    res.status(503).json({ 
      status: 'unhealthy', 
      database: 'disconnected',
      error: err.message 
    });
  }
});

// Get all todos
app.get('/api/todos', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM todos ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create todo
app.post('/api/todos', async (req, res) => {
  const { title } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO todos (title, completed) VALUES ($1, $2) RETURNING *',
      [title, false]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update todo
app.put('/api/todos/:id', async (req, res) => {
  const { id } = req.params;
  const { completed } = req.body;
  try {
    const result = await pool.query(
      'UPDATE todos SET completed = $1 WHERE id = $2 RETURNING *',
      [completed, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete todo
app.delete('/api/todos/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM todos WHERE id = $1', [id]);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // IMPORTANT for EC2

// Graceful shutdown
const server = app.listen(PORT, HOST, () => {
 // console.log(`Backend running on http://${HOST}:${PORT}`);
   console.log(`🚀 Backend running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server gracefully...');
  server.close(() => {
    console.log('HTTP server closed');
    pool.end(() => {
      console.log('Database pool closed');
      process.exit(0);
    });
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, closing server gracefully...');
  server.close(() => {
    console.log('HTTP server closed');
    pool.end(() => {
      console.log('Database pool closed');
      process.exit(0);
    });
  });
});
