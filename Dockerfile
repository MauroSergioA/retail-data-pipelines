FROM apache/hop:2.10.0

ENV HOP_PROJECT_NAME=superque
ENV HOP_PROJECT_FOLDER=/home/hop/project
ENV HOP_ENVIRONMENT_NAME=prod
ENV TZ=America/Sao_Paulo
ENV HOP_OPTIONS=-Xmx3g

USER root

RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
    "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/21.9.0.0/ojdbc8-21.9.0.0.jar" \
    -o /opt/hop/lib/ojdbc8.jar && \
    cp /opt/hop/lib/ojdbc8.jar /opt/hop/plugins/databases/oracle/ojdbc8.jar && \
    mkdir -p /opt/hop/plugins/databases/oracle/lib && \
    cp /opt/hop/lib/ojdbc8.jar /opt/hop/plugins/databases/oracle/lib/ojdbc8.jar

COPY --chown=hop:hop scripts/init-hop-vars.sh   /home/hop/init-hop-vars.sh
COPY --chown=root:root scripts/hop-entrypoint.sh /opt/hop/hop-entrypoint.sh
COPY --chown=root:root scripts/hop-run-server.py /opt/hop/hop-run-server.py
RUN chmod +x /home/hop/init-hop-vars.sh /opt/hop/hop-entrypoint.sh /opt/hop/hop-run-server.py

USER hop

COPY --chown=hop:hop consinco/    /home/hop/project/consinco/
COPY --chown=hop:hop workflows/   /home/hop/project/workflows/
COPY --chown=hop:hop metadata/    /home/hop/project/metadata/

EXPOSE 8080

ENTRYPOINT ["/opt/hop/hop-entrypoint.sh"]
