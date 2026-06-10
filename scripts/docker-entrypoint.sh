#!/bin/sh
# Docker Swarm does not inject host.docker.internal automatically (unlike Compose).
# Resolve it here as root before dropping privileges to the hop user.
GATEWAY=$(ip route show default 2>/dev/null | awk '/default/{print $3}')
if [ -n "$GATEWAY" ] && ! grep -q "host.docker.internal" /etc/hosts; then
    printf '%s\thost.docker.internal\n' "$GATEWAY" >> /etc/hosts
fi
exec su-exec hop /opt/hop/hop-entrypoint.sh
