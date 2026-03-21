const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const client = require('prom-client');

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


// Create a registry for metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const dbQueryDuration = new client.Histogram({
  name: 'db_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['query_type'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2]
});

const activeConnectionsGauge = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active HTTP connections'
});

const dbPoolGauge = new client.Gauge({
  name: 'db_pool_connections',
  help: 'Database connection pool status',
  labelNames: ['state']
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(dbQueryDuration);
register.registerMetric(activeConnectionsGauge);
register.registerMetric(dbPoolGauge);

let activeConnections = 0;

// Database connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'todoapp',
  user: process.env.DB_USER || 'todouser',
  password: DB_PASSWORD
});

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  activeConnections++;
  activeConnectionsGauge.set(activeConnections);
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
    
    activeConnections--;
    activeConnectionsGauge.set(activeConnections);
  });
  
  next();
});

// Update DB pool metrics periodically
setInterval(() => {
  dbPoolGauge.labels('total').set(pool.totalCount);
  dbPoolGauge.labels('idle').set(pool.idleCount);
  dbPoolGauge.labels('waiting').set(pool.waitingCount);
}, 5000);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health check endpoint.

app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
    checks: {}
  };

  let overallStatus = 'healthy';

  // Database connectivity
  try {
    const start = Date.now();
    await pool.query('SELECT 1');
    const responseTime = Date.now() - start;
    
    health.checks.database = {
      status: 'healthy',
      responseTime: `${responseTime}ms`,
      message: 'Database connection successful'
    };

    // Warn if database is slow
    if (responseTime > 1000) {
      health.checks.database.status = 'degraded';
      health.checks.database.warning = 'Slow response time';
      overallStatus = 'degraded';
    }
  } catch (err) {
    health.checks.database = {
      status: 'unhealthy',
      error: err.message
    };
    overallStatus = 'unhealthy';
  }

  // Database pool health
  const poolStats = {
    totalConnections: pool.totalCount,
    idleConnections: pool.idleCount,
    waitingRequests: pool.waitingCount
  };

  health.checks.databasePool = {
    status: 'healthy',
    ...poolStats
  };

  // Warn if pool is exhausted
  if (pool.waitingCount > 0) {
    health.checks.databasePool.status = 'degraded';
    health.checks.databasePool.warning = 'Connection pool under pressure';
    overallStatus = 'degraded';
  }

  // Memory usage
  const memUsage = process.memoryUsage();
  const memUsageMB = {
    rss: Math.round(memUsage.rss / 1024 / 1024),
    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
    external: Math.round(memUsage.external / 1024 / 1024)
  };

  health.checks.memory = {
    status: 'healthy',
    usage: memUsageMB,
    unit: 'MB'
  };

  // Warn if memory usage is high.
  if (memUsageMB.heapUsed > 400) {
    health.checks.memory.status = 'degraded';
    health.checks.memory.warning = 'High memory usage';
    overallStatus = 'degraded';
  }

  // Active connections
  health.checks.connections = {
    status: 'healthy',
    active: activeConnections
  };

  // Secrets loaded
  health.checks.secrets = {
    status: 'healthy',
    loaded: true
  };

  
  health.status = overallStatus;

  const statusCode = overallStatus === 'healthy' ? 200 : 
                     overallStatus === 'degraded' ? 200 : 503;

  res.status(statusCode).json(health);
});

// Readiness check
app.get('/ready', async (req, res) => {
  try {
    
    await pool.query('SELECT 1');
    res.status(200).json({ 
      ready: true,
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    res.status(503).json({ 
      ready: false,
      reason: 'Database not ready',
      error: err.message
    });
  }
});


app.get('/live', (req, res) => {
  res.status(200).json({ alive: true });
});

// Get all todos
app.get('/api/todos', async (req, res) => {
  const start = Date.now(); 
  
  try {
    const result = await pool.query('SELECT * FROM todos ORDER BY id DESC');
    
    const duration = (Date.now() - start) / 1000;
    dbQueryDuration.labels('select').observe(duration);
    
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Create todo
app.post('/api/todos', async (req, res) => {
  const start = Date.now();
  const { title } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO todos (title, completed) VALUES ($1, $2) RETURNING *',
      [title, false]
    );
    
    const duration = (Date.now() - start) / 1000;
    dbQueryDuration.labels('insert').observe(duration);
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update todo
app.put('/api/todos/:id', async (req, res) => {
  const start = Date.now();
  const { id } = req.params;
  const { completed } = req.body;
  try {
    const result = await pool.query(
      'UPDATE todos SET completed = $1 WHERE id = $2 RETURNING *',
      [completed, id]
    );
    
    const duration = (Date.now() - start) / 1000;
    dbQueryDuration.labels('update').observe(duration);
    
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete todo
app.delete('/api/todos/:id', async (req, res) => {
  const start = Date.now();
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM todos WHERE id = $1', [id]);
    
    const duration = (Date.now() - start) / 1000;
    dbQueryDuration.labels('delete').observe(duration);
    
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0'; // IMPORTANT for EC2


const server = app.listen(PORT, HOST, () => {
  console.log(`Backend running on http://${HOST}:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
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
