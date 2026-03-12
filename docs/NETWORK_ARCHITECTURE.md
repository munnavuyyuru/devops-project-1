# 🐳 Docker Network Architecture
<img width="700" height="700" alt="docker network isolation" src="https://github.com/user-attachments/assets/7800f477-2468-4dc2-b5b1-168702f72080" />


## 🔐 Security Benefits

1. **Database Isolation**
   - Database is NOT accessible from frontend
   - Database is NOT accessible from internet
   - Only backend can communicate with database

2. **Internal Network**
   - `backend-network` is marked as `internal: true`
   - Containers on this network cannot access external internet
   - Prevents data exfiltration if backend is compromised

3. **Minimal Port Exposure**
   - Only port 80 (frontend) exposed to internet
   - Backend port 3000 only for local testing (remove in production)
   - Database port 5432 NOT exposed at all

## Network Flow
#### Internet Request:
1. User → http://your-domain:80
2. Nginx (Frontend) receives request
3. Frontend makes API call to http://backend:3000
4. Backend queries database at database:5432
5. Response flows back: **DB → Backend → Frontend → User**



## Production Deployment

In production, remove backend port exposure:

```yaml
backend:
  # ports:  ← Remove this line
  #   - "3000:3000"
```
- Only expose frontend port 80/443 through a reverse proxy.

## Testing Network Isolation
1. #### Frontend CANNOT reach database (should fail)
```bash
docker exec todo-frontend ping -c 2 database
```
<img width="776" height="37" alt="image" src="https://github.com/user-attachments/assets/a5b49c56-aa73-46e4-90dd-b69775daf3e1" />


2. #### Backend CAN reach database (should succeed)
``` bash
docker exec todo-backend ping -c 2 database
```
<img width="765" height="145" alt="image" src="https://github.com/user-attachments/assets/6cd2ac6c-d9b0-4b91-9cee-0b939641ba4a" />


3. #### Backend CAN reach frontend (should succeed)
```bash
docker exec todo-backend ping -c 2 todo-frontend
```
<img width="806" height="149" alt="image" src="https://github.com/user-attachments/assets/863b3576-c9a0-4fc4-993b-775679c05fd2" />


## Security Summary
- Database isolated from public access
- Backend restricted to internal network
- Minimal exposed ports
- Clear separation between services
