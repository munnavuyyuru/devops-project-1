#!/bin/bash

echo "Starting real-time metrics monitor"
echo ""

while true; do
    clear
    echo "--------------------------------------------------"
    echo "        Application Metrics Dashboard"
    echo "--------------------------------------------------"
    echo ""
    
    echo "Current time: $(date)"
    echo ""
    
    # Request rate
    REQUESTS=$(curl -s 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[1m])' | \
               jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    REQUESTS=$(printf "%.2f" "$REQUESTS")
    echo "Request rate: $REQUESTS requests/sec"
    
    # Active connections
    ACTIVE=$(curl -s 'http://localhost:9090/api/v1/query?query=active_connections' | \
             jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    echo "Active HTTP connections: $ACTIVE"
    
    # Memory usage
    MEMORY=$(curl -s 'http://localhost:9090/api/v1/query?query=process_resident_memory_bytes' | \
             jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    MEMORY_MB=$(echo "scale=2; $MEMORY / 1024 / 1024" | bc 2>/dev/null || echo "0")
    echo "Memory usage: ${MEMORY_MB} MB"
    
    # DB pool status
    DB_TOTAL=$(curl -s 'http://localhost:9090/api/v1/query?query=db_pool_connections{state="total"}' | \
               jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    DB_IDLE=$(curl -s 'http://localhost:9090/api/v1/query?query=db_pool_connections{state="idle"}' | \
              jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    echo "Database pool: $DB_IDLE idle out of $DB_TOTAL total connections"
    
    echo ""
    echo "Container status:"
    docker compose ps 2>/dev/null | grep -E "NAME|todo-|prometheus|grafana|loki" || echo "No relevant containers running"
    
    echo ""
    echo "Refreshing in 5 seconds..."
    
    sleep 5
done
