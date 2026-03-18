#!/bin/bash

while true; do
    clear
    echo "╔════════════════════════════════════════════════╗"
    echo "║          SYSTEM HEALTH DASHBOARD               ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    date
    echo ""
    
    # Get health data
    HEALTH=$(curl -s http://localhost:3000/health)
    
    if [ $? -eq 0 ]; then
        STATUS=$(echo $HEALTH | jq -r '.status')
        DB_STATUS=$(echo $HEALTH | jq -r '.checks.database.status')
        DB_TIME=$(echo $HEALTH | jq -r '.checks.database.responseTime')
        MEM_USED=$(echo $HEALTH | jq -r '.checks.memory.usage.heapUsed')
        UPTIME=$(echo $HEALTH | jq -r '.uptime')
        ACTIVE_CONN=$(echo $HEALTH | jq -r '.checks.connections.active')
        
        echo "Overall Status: $STATUS"
        echo ""
        echo "📊 Components:"
        echo "  Database: $DB_STATUS ($DB_TIME)"
        echo "  Memory: ${MEM_USED}MB"
        echo "  Active Connections: $ACTIVE_CONN"
        echo "  Uptime: $(printf '%.0f' $UPTIME) seconds"
        echo ""
        
        # Container status
        echo "🐳 Containers:"
        docker compose ps --format "table {{.Name}}\t{{.Status}}" | grep -E "NAME|todo-"
        
    else
        echo "❌ Cannot reach backend health endpoint"
    fi
    
    sleep 5
done
