{ cfg, changeMaster, importDump }: ''
set -euo pipefail

ch="$1"
status=$(mktemp)
trap 'rm -f "$status"' EXIT

slave_status () {
  if ! ${cfg.package}/bin/mysql -e ';'; then
    echo unknown; return
  fi

  if ${cfg.package}/bin/mysql -e "SHOW SLAVE '$1' STATUS\\G" | sed 's,^ *,,' > "$status"; then
    if grep -oE '\bMaster_Server_Id:\s*[1-9][0-9]*' "$status" >&2; then
      io_errno=$(awk '/Last_IO_Errno:/ {print $2}' "$status")
      sql_errno=$(awk '/Last_SQL_Errno:/ {print $2}' "$status")
      case "$io_errno:$sql_errno" in
        0:0)
          echo ok
          return
          ;;
        0:*)
          awk '/Last_SQL_Error:/ {print $0}' "$status" >&2
          echo "sql_error:$sql_errno"
          return
          ;;
        *:*)
          awk '/Last_IO_Error:/ {print $0}' "$status" >&2
          echo "io_error:$io_errno"
          return
          ;;
      esac
    fi
  fi
  echo none
}

sql_errors=0
none_count=0
while true; do
  st=$(slave_status "$ch")

  case "$st" in
    ok|unknown)
      echo "status: $st" >&2
      exit
      ;;
    none)
      # XXX existing slave might not be initialized yet after mariadb restarts
      (( ++none_count ))
      echo "status: $st (count: $none_count)" >&2
      if [ "$none_count" -lt 10 ]; then
        sleep 1m
        continue
      fi
      ${cfg.package}/bin/mysql -v -N -e "CALL mysql.resetSlave('$ch')" >&2
      ${changeMaster} "$ch" | ${cfg.package}/bin/mysql
      if ${importDump} "$ch" | ${cfg.package}/bin/mysql; then
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.startSlave('$ch')" >&2
        exit
      else
        echo 'Import failed. Starting over' >&2
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.resetSlave('$ch')" >&2
        exit 1
      fi
      ;;
    io_error:*)
      echo "status: $st" >&2
      ${cfg.package}/bin/mysql -v -N -e "CALL mysql.stopSlave('$ch')" >&2
      ${changeMaster} "$ch" | ${cfg.package}/bin/mysql
      ${cfg.package}/bin/mysql -v -N -e "CALL mysql.startSlave('$ch')" >&2
      exit 1
      ;;
    sql_error:1205) # Lock wait timeout exceeded
      echo "status: $st" >&2
      ${cfg.package}/bin/mysql -v -N -e "CALL mysql.startSlave('$ch')" >&2
      exit 1
      ;;
    sql_error:*)
      (( ++sql_errors ))
      echo "status: $st (count: $sql_errors)" >&2
      if [ "$sql_errors" -le 1 ]; then
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.pauseSlave('$ch')" >&2
        sleep 1s
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.startSlave('$ch')" >&2
      elif [ "$sql_errors" -le 2 ]; then
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.stopSlave('$ch')" >&2
        # this *unlikely* *may* change replication option (ignore tables, etc.)
        ${changeMaster} "$ch" | ${cfg.package}/bin/mysql
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.startSlave('$ch')" >&2
      else
        echo '!!! Resetting slave !!!' >&2
        ${cfg.package}/bin/mysql -v -N -e "CALL mysql.resetSlave('$ch')" >&2
        exit 1
      fi
      sleep 2m
      ;;
    *) echo "BUG: $st" >&2; exit 255;;
  esac
  sleep 1s
done
''

