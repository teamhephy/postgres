#!/usr/bin/env bash

cat << EOF >> "$PGDATA/postgresql.conf"
wal_level = archive
archive_mode = on
archive_command = 'envdir "${WALE_ENVDIR}" wal-e wal-push %p'
archive_timeout = 60
EOF

# ensure $PGDATA has the right permissions
chown -R postgres:postgres "$PGDATA"
chmod 0700 "$PGDATA"

# reboot the server for wal_level to be set before backing up
echo "Rebooting postgres to enable archive mode"
su-exec postgres pg_ctl -D "$PGDATA" -w restart

# check if there are any backups -- if so, let's restore
# we could probably do better than just testing number of lines -- one line is just a heading, meaning no backups
if [[ $(envdir "$WALE_ENVDIR" wal-e --terse backup-list | wc -l) -gt "1" ]]; then
  echo "Found backups. Restoring from backup..."
  su-exec postgres pg_ctl -D "$PGDATA" -w stop
  envdir "$WALE_ENVDIR" wal-e backup-fetch "$PGDATA_RECOVERY" LATEST
  cat << EOF > "$PGDATA_RECOVERY/postgresql.conf"
# These settings are initialized by initdb, but they can be changed.
log_timezone = 'UTC'
lc_messages = 'C'     # locale for system error message
lc_monetary = 'C'     # locale for monetary formatting
lc_numeric = 'C'      # locale for number formatting
lc_time = 'C'       # locale for time formatting
default_text_search_config = 'pg_catalog.english'
wal_level = archive
archive_mode = on
archive_command = 'envdir "${WALE_ENVDIR}" wal-e wal-push %p'
archive_timeout = 60
listen_addresses = '*'
unix_socket_directories = '/var/run/postgresql'
EOF
  cat << EOF > "$PGDATA_RECOVERY/pg_hba.conf"
# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
# IPv4 global connections
host    all             all             0.0.0.0/0               md5
EOF
  touch "$PGDATA_RECOVERY/pg_ident.conf"
  echo "restore_command = 'envdir /etc/wal-e.d/env wal-e wal-fetch \"%f\" \"%p\"'" >> "$PGDATA_RECOVERY/recovery.conf"
  chown -R postgres:postgres "$PGDATA_RECOVERY"
  chmod 0700 "$PGDATA_RECOVERY"

  POSTGRES_OLD_VERSION=$(cat "$PGDATA_RECOVERY"/PG_VERSION)
  if [ "$POSTGRES_OLD_VERSION" = "$PG_MAJOR" ] ; then
    su-exec postgres rm -rf "$PGDATA"/*
    su-exec postgres cp -rf "$PGDATA_RECOVERY"/* "$PGDATA"
  else
    do_upgrade "$PGDATA_RECOVERY" "$PGDATA"
  fi
  su-exec postgres pg_ctl \
    -D "$PGDATA" \
    -o "-c listen_addresses=''" \
    -w start
fi

# ensure $PGDATA has the right permissions
chown -R postgres:postgres "$PGDATA"
chmod 0700 "$PGDATA"
