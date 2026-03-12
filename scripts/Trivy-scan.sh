#!/bin/bash

echo "============================================"
echo "   Docker Image Security Scan (Trivy)"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_CODE=0

echo "📦 Scanning base images..."
echo ""

# Scan base images
echo " Scanning postgres:16-alpine..."
if trivy image --severity HIGH,CRITICAL --quiet postgres:16-alpine; then
    echo -e "${GREEN}✅ PostgreSQL base image: No HIGH/CRITICAL vulnerabilities${NC}"
else
    echo -e "${RED}❌ PostgreSQL base image: Vulnerabilities found${NC}"
    EXIT_CODE=1
fi
echo ""

echo " Scanning node:18-alpine..."
if trivy image --severity HIGH,CRITICAL --quiet node:18-alpine; then
    echo -e "${GREEN}✅ Node base image: No HIGH/CRITICAL vulnerabilities${NC}"
else
    echo -e "${RED}❌ Node base image: Vulnerabilities found${NC}"
    EXIT_CODE=1
fi
echo ""

echo " Scanning nginx:1.25-alpine..."
if trivy image --severity HIGH,CRITICAL --quiet nginx:1.25-alpine; then
    echo -e "${GREEN}✅ Nginx base image: No HIGH/CRITICAL vulnerabilities${NC}"
else
    echo -e "${RED}❌ Nginx base image: Vulnerabilities found${NC}"
    EXIT_CODE=1
fi
echo ""

echo "============================================"
echo " Scanning application images..."
echo ""

# Scan built images
echo "  Scanning backend image..."
if trivy image --severity HIGH,CRITICAL --quiet devops-project-backend; then
    echo -e "${GREEN}✅ Backend image: No HIGH/CRITICAL vulnerabilities${NC}"
else
    echo -e "${RED}❌ Backend image: Vulnerabilities found${NC}"
    EXIT_CODE=1
fi
echo ""

echo " Scanning frontend image..."
if trivy image --severity HIGH,CRITICAL --quiet devops-project-frontend; then
    echo -e "${GREEN}✅ Frontend image: No HIGH/CRITICAL vulnerabilities${NC}"
else
    echo -e "${RED}❌ Frontend image: Vulnerabilities found${NC}"
    EXIT_CODE=1
fi
echo ""

echo "============================================"
echo "📊 Scan Summary"
echo "============================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All images passed security scan${NC}"
    echo "Safe to deploy!"
else
    echo -e "${RED}❌ Security vulnerabilities detected${NC}"
    echo "Review the vulnerabilities above before deploying."
    echo ""
    echo "To see full details, run:"
    echo "  trivy image --severity HIGH,CRITICAL <image-name>"
fi

exit $EXIT_CODE
