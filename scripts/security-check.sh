#!/bin/bash

echo " ===Container Security Configuration Check==="


# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_security() {
local container=$1
local check_name=$2
local command=$3

if docker exec $container sh -c "$command" > /dev/null 2>&1; then
echo -e "${GREEN}✅ $check_name${NC}"
((PASS++))
else
echo -e "${RED}❌ $check_name${NC}"
((FAIL++))
fi
}

echo "===🔒 Checking Backend Security==="

# Check read-only filesystem
echo "📁 Read-Only Filesystem:"
if ! docker exec todo-backend touch /app/test.txt 2>/dev/null; then
echo -e "${GREEN}✅ Backend filesystem is read-only${NC}"
((PASS++))
else
echo -e "${RED}❌ Backend filesystem is writable${NC}"
((FAIL++))
fi

# Check capabilities

echo "===🛡️ Linux Capabilities==="
CAP_COUNT=$(docker exec todo-backend sh -c "cat /proc/1/status | grep CapEff" | awk '{print $2}')
if [ "$CAP_COUNT" = "0000000000000000" ]; then
echo -e "${GREEN}✅ All capabilities dropped (backend)${NC}"
((PASS++))
else
echo -e "${YELLOW}⚠️ Backend has some capabilities: $CAP_COUNT${NC}"
((FAIL++))
fi

# Check no-new-privileges

echo "===🔐 Privilege Escalation Protection==="
NO_NEW_PRIVS=$(docker inspect todo-backend --format='{{.HostConfig.SecurityOpt}}')
if [[ $NO_NEW_PRIVS == *"no-new-privileges:true"* ]]; then
echo -e "${GREEN}✅ no-new-privileges enabled (backend)${NC}"
((PASS++))
else
echo -e "${RED}❌ no-new-privileges NOT enabled (backend)${NC}"
((FAIL++))
fi

# Check PID limit

echo "=== Fork Bomb Protection==="
PID_LIMIT=$(docker inspect todo-backend --format='{{.HostConfig.PidsLimit}}')
if [ "$PID_LIMIT" != "0" ] && [ "$PID_LIMIT" != "" ]; then
echo -e "${GREEN}✅ PID limit set: $PID_LIMIT${NC}"
((PASS++))
else
echo -e "${RED}❌ No PID limit set${NC}"
((FAIL++))
fi



echo "===Checking Frontend Security==="


# Check read-only filesystem
echo "📁 Read-Only Filesystem:"
if ! docker exec todo-frontend touch /usr/share/nginx/html/test.html 2>/dev/null; then
echo -e "${GREEN}✅ Frontend filesystem is read-only${NC}"
((PASS++))
else
echo -e "${RED}❌ Frontend filesystem is writable${NC}"
((FAIL++))
fi


echo "=== Checking Database Security==="

# Check read-only filesystem
echo "📁 Read-Only Filesystem:"
if ! docker exec todo-database touch /test.txt 2>/dev/null; then
echo -e "${GREEN}✅ Database filesystem is read-only${NC}"
((PASS++))
else
echo -e "${RED}❌ Database filesystem is writable${NC}"
((FAIL++))
fi

# Check secrets are NOT in environment
echo ""
echo " ===Secrets Protection==="
if ! docker exec todo-backend env | grep -i "DB_PASSWORD="; then
echo -e "${GREEN}✅ Database password NOT in environment variables${NC}"
((PASS++))
else
echo -e "${RED}❌ Database password EXPOSED in environment variables${NC}"
((FAIL++))
fi

echo ""
echo "============================================"
echo "📊 Security Check Summary"
echo "============================================"
echo ""
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
echo -e "${GREEN}✅ All security checks passed!${NC}"
echo "Safe for production deployment."
exit 0
else
echo -e "${RED}❌ Security vulnerabilities detected!${NC}"
echo "Fix the issues above before deploying."
exit 1
fi
