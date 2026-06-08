FROM apache/hop:2.10.0

ENV HOP_PROJECT_NAME=superque
ENV HOP_PROJECT_FOLDER=/home/hop/project
ENV HOP_ENVIRONMENT_NAME=prod
ENV HOP_SERVER_PORT=8080
ENV HOP_SERVER_HOSTNAME=0.0.0.0

COPY --chown=hop:hop consinco/    /home/hop/project/consinco/
COPY --chown=hop:hop workflows/   /home/hop/project/workflows/
COPY --chown=hop:hop metadata/    /home/hop/project/metadata/

EXPOSE 8080

CMD ["/bin/bash", "-c", \
  "hop-server.sh \
    --hostname ${HOP_SERVER_HOSTNAME} \
    --port ${HOP_SERVER_PORT} \
    --password ${HOP_SERVER_PASSWORD}"]
