#!/bin/bash
LOGFILE="/logs/orchestrator.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"
}

# Health check functions
check_mosquitto() { mosquitto_pub -h localhost -t "orchestrator/health" -m "ok" >/dev/null 2>&1; }
check_zigbee2mqtt() { wget -q --spider http://localhost:8080; }
check_homeassistant() { wget -q --spider http://localhost:8123; }
check_nodered() { wget -q --spider http://localhost:1880; }
check_frigate() { wget -q --spider http://localhost:5000; }
check_plex() { nc -z localhost 32400; }
check_scrypted() { wget -q --spider https://localhost:10443 --no-check-certificate; }

# Ordered services: name:health_function
SERVICES=(
    "mosquitto:check_mosquitto"
    "zigbee2mqtt:check_zigbee2mqtt"
    "homeassistant:check_homeassistant"
    "nodered:check_nodered"
    "frigate:check_frigate"
    "plex:check_plex"
    "scrypted:check_scrypted"
)

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
    log "ERROR: $name did not become healthy in time!"
    return 1
}

start_service() {
    local name=$1
    log "Starting service: $name"
    docker start "$name" >/dev/null 2>&1 || log "Failed to start $name"
}

collect_logs() {
    for name in $(docker ps --format '{{.Names}}'); do
        docker logs -f "$name" 2>&1 | sed "s/^/[$name] /" >> "$LOGFILE" &
    done
}

# MAIN
log "=== Orchestrator started ==="
collect_logs

for entry in "${SERVICES[@]}"; do
    service="${entry%%:*}"
    health="${entry##*:}"
    start_service "$service"
    wait_for "$service" "$health"
done

log "All services started. Entering monitoring loop..."
while true; do
    for entry in "${SERVICES[@]}"; do
        service="${entry%%:*}"
        health="${entry##*:}"
        if ! $health; then
            log "ALERT: $service unhealthy. Restarting..."
            docker restart "$service"
            wait_for "$service" "$health"
        fi
    done
    sleep 10
done
