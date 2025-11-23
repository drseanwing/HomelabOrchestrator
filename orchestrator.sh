#!/bin/bash
LOGFILE="/logs/orchestrator.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"
}

# Health check functions
check_mosquitto() { mosquitto_pub -h localhost -t "orchestrator/health" -m "ok" >/dev/null 2>&1; }
check_zigbee2mqtt() { wget -q --spider http://localhost:8080; }
check_homeassistant() { wget -q --spider http://localhost:8123; }
# ... other health check functions

SERVICES=(
    "mosquitto:check_mosquitto"
    "zigbee2mqtt:check_zigbee2mqtt"
    "homeassistant:check_homeassistant"
    # etc
)

# Function to wait for health
wait_for() {
    local name=$1
    local check_fn=$2
    log "Waiting for $name..."
    for i in {1..60}; do
        if $check_fn; then
            log "$name is healthy."
            return 0
        fi
        sleep 2
    done
    log "ERROR: $name did not become healthy!"
    return 1
}

start_service() {
    local name=$1
    log "Starting service: $name"
    docker start "$name" >/dev/null 2>&1 || log "Failed to start $name"
    return 0
}

collect_logs() {
    for name in $(docker ps --format '{{.Names}}'); do
        docker logs -f "$name" 2>&1 | sed "s/^/[$name] /" >> "$LOGFILE" &
    done
}

# Main orchestration
log "=== Orchestrator started ==="
collect_logs
for entry in "${SERVICES[@]}"; do
    service="${entry%%:*}"
    health="${entry##*:}"
    start_service "$service"
    wait_for "$service" "$health"
done

while true; do
    for entry in "${SERVICES[@]}"; do
        service="${entry%%:*}"
        health="${entry##*:}"
        if ! $health; then
            log "ALERT: $service unhealthy, restarting..."
            docker restart "$service"
            wait_for "$service" "$health"
        fi
    done
    sleep 10
done
