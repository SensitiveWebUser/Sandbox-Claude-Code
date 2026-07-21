#!/bin/sh
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# scc entrypoint: runs as root only to: remap 'node' to the host UID/GID (so
# mounted-repo files are owned by you; edits the container's own /etc/passwd,
# never host namespaces), fix home-volume ownership, and optionally raise the
# egress firewall (SCC_FIREWALL=1), then drops to node via gosu and execs.
set -eu

TARGET_UID="${HOST_UID:-1000}"
TARGET_GID="${HOST_GID:-$TARGET_UID}"

if [ "$(id -u)" = "0" ]; then
    run_as=node
    # Normally remap 'node' to the host UID/GID by editing /etc/passwd. Under a
    # read-only rootfs (scc --hardened) /etc can't be written, so run as the
    # numeric host uid:gid instead (HOME is set via ENV, so tools still work).
    if touch /etc/.scc-rwtest 2>/dev/null; then
        rm -f /etc/.scc-rwtest
        [ "$(id -g node)" = "$TARGET_GID" ] || groupmod -o -g "$TARGET_GID" node
        [ "$(id -u node)" = "$TARGET_UID" ] || usermod  -o -u "$TARGET_UID" node
    else
        run_as="${TARGET_UID}:${TARGET_GID}"
    fi

    if [ "$(stat -c %u /home/node)" != "$TARGET_UID" ] || \
       [ "$(stat -c %g /home/node)" != "$TARGET_GID" ]; then
        chown -R "$TARGET_UID:$TARGET_GID" /home/node
    fi

    if [ "${SCC_FIREWALL:-0}" = "1" ]; then
        /usr/local/bin/init-firewall.sh
    fi

    exec gosu "$run_as" "$@"
fi

# Already non-root (e.g. started with --user): nothing to set up.
exec "$@"
