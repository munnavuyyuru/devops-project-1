#!/bin/bash

LOKI_URL="http://localhost:3100"

CONTAINER=""
LEVEL=""
FOLLOW=false
LINES=100
SEARCH=""
TIME="1h"

while getopts "c:l:fn:s:t:" opt; do
    case $opt in
        c) CONTAINER=$OPTARG ;;
        l) LEVEL=$OPTARG ;;
        f) FOLLOW=true ;;
        n) LINES=$OPTARG ;;
        s) SEARCH=$OPTARG ;;
        t) TIME=$OPTARG ;;
        *) exit 1 ;;
    esac
done

# Portable time parsing
parse_time() {
    now=$(date +%s)

    case "$TIME" in
        *h) echo $((now - ${TIME%h} * 3600)) ;;
        *m) echo $((now - ${TIME%m} * 60)) ;;
        *s) echo $((now - ${TIME%s})) ;;
        *) echo $now ;;
    esac
}

# Build LogQL query
QUERY="{container_name=~\".+\"}"

if [ -n "$CONTAINER" ]; then
    QUERY="{container_name=\"todo-$CONTAINER\"}"
fi

if [ -n "$SEARCH" ]; then
    QUERY="$QUERY |~ \"$SEARCH\""
fi

if [ -n "$LEVEL" ]; then
    QUERY="$QUERY |~ \"(?i)$LEVEL\""
fi

if [ "$FOLLOW" = true ]; then
    while true; do
        START=$(parse_time)000000000
        END=$(date +%s)000000000

        RESULT=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
            --data-urlencode "query=$QUERY" \
            --data-urlencode "limit=$LINES" \
            --data-urlencode "start=$START" \
            --data-urlencode "end=$END")

        echo "$RESULT" | jq -r '.data.result[].values[].[1]' 2>/dev/null | tail -20
        sleep 2
        clear
    done
else
    START=$(parse_time)000000000
    END=$(date +%s)000000000

    RESULT=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query=$QUERY" \
        --data-urlencode "limit=$LINES" \
        --data-urlencode "start=$START" \
        --data-urlencode "end=$END")

    echo "$RESULT" | jq -r '.data.result[].values[].[1]' 2>/dev/null || echo "No logs found"
fi
