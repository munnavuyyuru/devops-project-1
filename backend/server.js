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

function loadSecret(secretName) {
  try {
    const productionPath = `/run/secrets/${secretName}`;
    const devPath = path.join(__dirname, '..', 'secrets', `${secretName}.txt`);
    
    if (fs.existsSync(productionPath)) {
      return fs.readFileSync(productionPath, 'utf8').trim();
    } else if (fs.existsSync(devPath)) {
      return fs.readFileSync(devPath, 'utf8').trim();
    } else {
      throw new Error(`Secret ${secretName} not found`);
    }
  } catch (err) {
    console.error(`FATAL: Cannot load secret ${secretName}:`, err.message);
    process.exit(1);
  }
}

const DB_PASSWORD = loadSecret('db_password');
const JWT_SECRET = loadSecret('jwt_secret');

console.log('Secrets loaded successfully');

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'todoapp',
  user: process.env.DB_USER || 'todouser',
  password: DB_PASSWORD
});

// Track active connections
let activeConnections = 0;

app.use((req, res, next) => {
  activeConnections++;
  res.on('finish', () => {
    activeConnections--;
  });
  next();
});

// Health check endpoint (CRITICAL for production)
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString(),
      secrets: 'loaded',
      activeConnections: activeConnections	    
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


const server = app.listen(PORT, HOST, () => {
  console.log(`?? Backend running on http://${HOST}:${PORT}`);
  console.log(`?? Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
let isShuttingDown = false;

async function gracefulShutdown(signal) {
  if (isShuttingDown) {
    console.log('Shutdown already in progress...');
    return;
  }
  
  isShuttingDown = true;
  console.log(`\n${signal} received. Starting graceful shutdown...`);
  console.log(`Active connections: ${activeConnections}`);
  
  //Stop accepting new requests
  server.close((err) => {
    if (err) {
      console.error('Error closing HTTP server:', err);
    } else {
      console.log('HTTP server closed ');
    }
  });
  
  // Wait for active connections to finish (with timeout)
  const shutdownTimeout = 25000; // 25 seconds 
  const checkInterval = 100;
  let elapsed = 0;
  
  while (activeConnections > 0 && elapsed < shutdownTimeout) {
    console.log(` Waiting for ${activeConnections} active connections to finish...`);
    await new Promise(resolve => setTimeout(resolve, checkInterval));
    elapsed += checkInterval;
  }
  
  if (activeConnections > 0) {
    console.log(` Forcing shutdown with ${activeConnections} active connections remaining`);
  } else {
    console.log(' All connections closed cleanly');
  }
  
  // Step 3: Close database pool
  try {
    await pool.end();
    console.log(' Database pool closed');
  } catch (err) {
    console.error(' Error closing database pool:', err);
  }
  
  console.log(' Shutdown complete. Goodbye!');
  process.exit(0);
}

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught errors gracefully
process.on('uncaughtException', (err) => {
  console.error(' Uncaught Exception:', err);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(' Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('UNHANDLED_REJECTION');
});
