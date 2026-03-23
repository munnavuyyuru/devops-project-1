# DevOps Todo Application - Dockerized 3-Tier Architecture

## 🏗️ Architecture
<img width="500" height="500" alt="devops todo app 3 tire dockerzied archi" src="https://github.com/user-attachments/assets/87a0a1c1-74ab-464e-b3a6-d8f94231233c" />


## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/munnavuyyuru/devops-project-1.git
cd devops-project

# Start all services
make up

# Check health
make health

# View logs
make logs

# Access the application
http://localhost
```

## 📋 Prerequisites
- Docker 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum
- Ports 80, 3000, 5432 available

## 🛠️ Commands
``` bash
make build    # Build all containers
make up       # Start services 
make down     # Stop services
make restart  # Restart all services
make logs     # View logs
make ps       # List containers
make clean    # Remove everything
```

## 📊 Monitoring
### Health Checks
1. Frontend: http://localhost/health
2. Backend: http://localhost:3000/health
3. Database: Automatic via pg_isready

## Check Service Status
```bash
docker compose ps
```
### Expected output:
<img width="800" height="100" alt="image" src="https://github.com/user-attachments/assets/512c16be-f270-4acc-9098-6492d6130a52" />


## 🔒 Security Features
1. ✅ Non-root users in all containers
2. ✅ Health checks on all services
3. ✅ Resource limits (CPU + Memory)
4. ✅ Restart policies
5. ✅ Read-only filesystems (where applicable)
6. ✅ Log rotation
7. ✅ Secrets management ready


## 💻 system overview

<img width="1051" height="479" alt="image" src="https://github.com/user-attachments/assets/64002aab-3175-4427-9084-abd0c940d37a" />

### Access Dashboards:

- Grafana: **http://localhost:3001 (admin/admin)**
- Prometheus: **http://localhost:9090**

## 📦 Production Deployment
See [DEPLOYMENT.md](./DEPLOYMENT.md) for AWS deployment instructions.


## 🔧 Troubleshooting
1. Container won't start
```bash
docker compose logs <service-name>
```
2. Database connection failed
```bash
docker exec -it todo-database pg_isready -U todouser -d todoapp
```
3. Reset everything
```bash
make clean
make build
make up
```

## 📝 Technical Decisions
- **Alpine Linux**: Smaller image size (5x smaller than full images)
- **Multi-stage builds**: Reduces final image size
- **Health checks**: Ensures containers are actually ready
- **Named volumes**: Persistent data storage
- **Resource limits**: Prevents resource exhaustion

## 📈 Performance
- Frontend image: ~75MB
- Backend image: ~190MB
- Total startup time: <30 seconds
- Memory usage: <1GB for all services

### 🏆 Production-Ready Features
1. ✅ Graceful shutdown handling
2. ✅ Automatic restart on crash
3. ✅ Health monitoring
4. ✅ Log aggregation ready
5. ✅ Secrets management ready
6. ✅ Resource constraints
7. ✅ Multi-environment support

### 👨‍💻 Author
**venkata bhargav vuyyuru**
