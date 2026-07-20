#!/bin/sh
# scc entrypoint — runs as root only long enough to:
#   1. remap the in-container 'node' user to the host UID/GID, so files
#      written to the mounted repo are owned by you on the host (this edits
#      the container's own /etc/passwd; host namespaces are never touched)
#   2. fix ownership of the persisted home volume, once, if needed
#   3. optionally raise the default-deny egress firewall (SCC_FIREWALL=1)
# then drops privileges with gosu and execs the requested command.
set -eu

TARGET_UID="${HOST_UID:-1000}"
TARGET_GID="${HOST_GID:-$TARGET_UID}"

if [ "$(id -u)" = "0" ]; then
    [ "$(id -g node)" = "$TARGET_GID" ] || groupmod -o -g "$TARGET_GID" node
    [ "$(id -u node)" = "$TARGET_UID" ] || usermod  -o -u "$TARGET_UID" node

    if [ "$(stat -c %u /home/node)" != "$TARGET_UID" ] || \
       [ "$(stat -c %g /home/node)" != "$TARGET_GID" ]; then
        chown -R "$TARGET_UID:$TARGET_GID" /home/node
    fi

    if [ "${SCC_FIREWALL:-0}" = "1" ]; then
        /usr/local/bin/init-firewall.sh
    fi

    exec gosu node "$@"
fi

# Already non-root (e.g. started with --user): nothing to set up.
exec "$@"
