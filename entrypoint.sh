#!/bin/bash

ODOO_RC=/opt/odoo/odoo.conf

set -e

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:='db'}
: ${PORT:=5432}
: ${USER:='odoo'}
: ${PASSWORD:='odoo'}
: ${LOGFILE:='/var/log/odoo/odoo-server.log'}


DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
   fi;
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"
check_config "logfile" "$LOGFILE"
check_config "config" "$ODOO_RC"

case "$1" in
    -- | /opt/odoo/odoo-server/odoo-bin)
        shift

          exec /opt/odoo/odoo-server/odoo-bin "$@" "${DB_ARGS[@]}"

        ;;
    -*)
        exec /opt/odoo/odoo-server/odoo-bin "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec /opt/odoo/odoo-server/odoo-bin "$@"
esac

exit 1