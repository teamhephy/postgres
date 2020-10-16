#!/usr/bin/env bash

#set -eof pipefail

cleanup() {
  kill-containers "${SWIFT_DATA}" "${SWIFT_JOB}" "${PG_JOB}"
}
trap cleanup EXIT

waitting-install-apk() {
  sleep 30s
  apk_running="apk"
  puts-step "Installing apk, coffee"
  while true
  do
    apk_running=$(docker exec "${PG_JOB}" "ps -ef|grep apk|grep -v grep")
    if [ -z "$apk_running" ] ; then
        break
    fi
    puts-step "..."
    sleep 10s
  done
  echo "Install apk process is complete"
}

TEST_ROOT=$(dirname "${BASH_SOURCE[0]}")/
# shellcheck source=/dev/null
source "${TEST_ROOT}/test.sh"

# make sure we are in this dir
CURRENT_DIR=$(cd "$(dirname "$0")"|| exit; pwd)

create-postgres-creds

puts-step "fetching openstack credentials"

# turn creds into something that we can use.
mkdir -p "${CURRENT_DIR}"/tmp/swift

# guess which value to use for tenant:
TENANT=""

echo "test:tester" > "${CURRENT_DIR}"/tmp/swift/username
echo "testing" > "${CURRENT_DIR}"/tmp/swift/password
echo "${TENANT}" > "${CURRENT_DIR}"/tmp/swift/tenant
echo "http://swift:8080/auth/v1.0" > "${CURRENT_DIR}"/tmp/swift/authurl
echo "1" > "${CURRENT_DIR}"/tmp/swift/authversion
echo "deis-swift-test" > "${CURRENT_DIR}"/tmp/swift/database-container

# boot swift
SWIFT_DATA=$(docker run -d -v /srv --name SWIFT_DATA busybox)

SWIFT_JOB=$(docker run -d --name onlyone --hostname onlyone --volumes-from SWIFT_DATA -t deis/swift-onlyone:git-8516d23)

test-upgrade-from(){
  PGDATA_DIR=${CURRENT_DIR}/tmp/postgres/tmp_$(date +%s)
  mkdir -p "$PGDATA_DIR"

  docker run --rm \
    -v "${PGDATA_DIR}:/var/lib/postgres/pg_data" \
    -e PGDATA=/var/lib/postgres/pg_data \
    "$1" \
    bash -c "chown -R postgres /var/lib/postgres/pg_data && su-exec postgres initdb"

  PG_CMD="docker run -d --link ${SWIFT_JOB}:swift -e BACKUP_FREQUENCY=3s \
    -e DATABASE_STORAGE=swift \
    -e PGCTLTIMEOUT=1200 \
    -e PGDATA=/var/lib/postgres/pg_data \
    -v ${PGDATA_DIR}:/var/lib/postgres/pg_data \
    -v ${CURRENT_DIR}/tmp/creds:/var/run/secrets/deis/database/creds \
    -v ${CURRENT_DIR}/tmp/swift:/var/run/secrets/deis/objectstore/creds \
    $IMAGE"
  PG_JOB=$($PG_CMD)
  sleep 90s
  puts-step "sleeping for 90s while postgres is restore..."

  check-postgres "${PG_JOB}"
  puts-step "postgres upgrade from $1"
}

test-upgrade-from-wal() {
  PG_CMD="docker run -d --link ${SWIFT_JOB}:swift -e BACKUP_FREQUENCY=3s \
     -e DATABASE_STORAGE=swift \
     -e PGCTLTIMEOUT=1200 \
     -v ${CURRENT_DIR}/tmp/creds:/var/run/secrets/deis/database/creds \
     -v ${CURRENT_DIR}/tmp/swift:/var/run/secrets/deis/objectstore/creds \
     $1"

  start-postgres "$PG_CMD"
  # display logs for debugging purposes
  puts-step "displaying swift logs"
  docker logs "${SWIFT_JOB}"
  check-postgres "${PG_JOB}"
  puts-step "shutting off postgres, then rebooting to test data recovery"
  kill-containers "${PG_JOB}"

  PG_CMD="docker run -d --link ${SWIFT_JOB}:swift -e BACKUP_FREQUENCY=3s \
     -e DATABASE_STORAGE=swift \
     -e PGCTLTIMEOUT=1200 \
     -v ${CURRENT_DIR}/tmp/creds:/var/run/secrets/deis/database/creds \
     -v ${CURRENT_DIR}/tmp/swift:/var/run/secrets/deis/objectstore/creds \
     $IMAGE"

  start-postgres "${PG_CMD}"

  check-postgres "${PG_JOB}"
}

IMAGE="$1"

test-upgrade-from postgres:9.4-alpine
kill-containers "${PG_JOB}"

test-upgrade-from postgres:9.5-alpine
kill-containers "${PG_JOB}"

test-upgrade-from postgres:9.6-alpine
kill-containers "${PG_JOB}"

test-upgrade-from postgres:10-alpine
kill-containers "${PG_JOB}"

test-upgrade-from postgres:11-alpine
kill-containers "${PG_JOB}"

test-upgrade-from-wal hephy/postgres:v2.7.5

puts-step "tests PASSED!"
exit 0
