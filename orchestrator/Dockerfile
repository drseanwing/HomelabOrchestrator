FROM alpine:3.19

# Install bash, wget, curl, coreutils, mosquitto clients, netcat, and Docker CLI
RUN apk add --no-cache bash wget curl coreutils mosquitto-clients netcat-openbsd docker-cli

COPY orchestrator.sh /usr/local/bin/orchestrator.sh
RUN chmod +x /usr/local/bin/orchestrator.sh

CMD ["/usr/local/bin/orchestrator.sh"]
