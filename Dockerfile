FROM apache/hop:2.10.0

ENV HOP_PROJECT_NAME=superque
ENV HOP_PROJECT_FOLDER=/home/hop/project
ENV HOP_ENVIRONMENT_NAME=prod
ENV HOP_SERVER_PORT=8080
ENV HOP_SERVER_HOSTNAME=0.0.0.0
ENV HOP_CUSTOM_ENTRYPOINT_EXTENSION_SHELL_FILE_PATH=/home/hop/init-hop-vars.sh

USER root
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.9.0.0/ojdbc8-21.9.0.0.jar" \
    -o /opt/hop/lib/ojdbc8.jar && \
    cp /opt/hop/lib/ojdbc8.jar /opt/hop/plugins/databases/oracle/ojdbc8.jar && \
    mkdir -p /opt/hop/plugins/databases/oracle/lib && \
    cp /opt/hop/lib/ojdbc8.jar /opt/hop/plugins/databases/oracle/lib/ojdbc8.jar

COPY --chown=hop:hop scripts/init-hop-vars.sh /home/hop/init-hop-vars.sh
RUN chmod +x /home/hop/init-hop-vars.sh

USER hop

COPY --chown=hop:hop consinco/    /home/hop/project/consinco/
COPY --chown=hop:hop workflows/   /home/hop/project/workflows/
COPY --chown=hop:hop metadata/    /home/hop/project/metadata/

EXPOSE 8080
