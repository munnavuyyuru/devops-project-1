#!/bin/bash

echo "============================================"
echo "   Testing Graceful Shutdown"
echo "============================================"
echo ""

# Start a load test in background
echo "1.Starting continuous requests to backend..."
(
  for i in {1..60}; do
    curl -s http://localhost:3000/api/todos > /dev/null &
    sleep 0.5
  done
) &
LOAD_PID=$!

sleep 2

echo "2. Sending SIGTERM to backend container..."
docker kill --signal=SIGTERM todo-backend

echo "3. Monitoring shutdown process..."
echo ""

# Watch logs for graceful shutdown
timeout 15 docker logs -f todo-backend 2>&1 | grep -E "SIGTERM|closing|closed" &
LOG_PID=$!

# Wait for container to stop
SECONDS=0
while docker ps | grep -q todo-backend; do
    sleep 1
    if [ $SECONDS -gt 15 ]; then
        echo "❌ Container took too long to stop (forced SIGKILL)"
        break
    fi
done

echo ""
echo "⏱️  Shutdown time: ${SECONDS} seconds"

# Cleanup
kill $LOAD_PID 2>/dev/null
kill $LOG_PID 2>/dev/null

# Restart the container
echo ""
echo "4. Restarting container..."
docker compose up -d backend

echo ""
echo "✅ Test complete!"
