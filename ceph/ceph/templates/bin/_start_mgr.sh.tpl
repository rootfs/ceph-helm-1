#!/bin/bash
set -ex

source variables_entrypoint.sh
source common_functions.sh

if [[ ! -e /usr/bin/ceph-mgr ]]; then
  log "ERROR- /usr/bin/ceph-mgr doesn't exist"
  sleep infinity
fi

if [[ ! -e /etc/ceph/${CLUSTER}.conf ]]; then
  log "ERROR- /etc/ceph/${CLUSTER}.conf must exist; get it from your existing mon"
  exit 1
fi

if [ ${CEPH_GET_ADMIN_KEY} -eq 1 ]; then
  if [[ ! -e $ADMIN_KEYRING ]]; then
      log "ERROR- $ADMIN_KEYRING must exist; get it from your existing mon"
      exit 1
  fi
fi

# Check to see if our MGR has been initialized
if [ ! -e "$MGR_KEYRING" ]; then
    # Create ceph-mgr key
    timeout 10 ceph ${CLI_OPTS} auth get-or-create mgr."$MGR_NAME" mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o "$MGR_KEYRING"
    chown --verbose ceph. "$MGR_KEYRING"
    chmod 600 "$MGR_KEYRING"
fi

log "SUCCESS"

ceph -v 

if [[ "$MGR_DASHBOARD" == 1 ]]; then
    ceph ${CLI_OPTS} mgr module enable dashboard --force
    ceph ${CLI_OPTS} config-key put mgr/dashboard/server_addr "$MGR_IP"
    ceph ${CLI_OPTS} config-key put mgr/dashboard/server_port "$MGR_PORT"
fi

if [[ "$LOCAL_POOL" == 1 ]]; then
    ceph ${CLI_OPTS} mgr module enable localpool --force
    if [ -n "${LPOOL_FAILURE_DOMAIN}" ]; then
        ceph ${CLI_OPTS} config-key set mgr/localpool/failure_domain ${LPOOL_FAILURE_DOMAIN}
    fi
    if [ -n "${LPOOL_SUBTREE}" ]; then
        ceph ${CLI_OPTS} config-key set mgr/localpool/subtree ${LPOOL_SUBTREE}
    fi
    if [ -n "${LPOOL_PG_NUM}" ]; then
        ceph ${CLI_OPTS} config-key set mgr/localpool/pg_num ${LPOOL_PG_NUM}
    fi
    if [ -n "${LPOOL_NUM_REP}" ]; then
        ceph ${CLI_OPTS} config-key set mgr/localpool/num_rep ${LPOOL_NUM_REP}
    fi
    if [ -n "${LPOOL_MIN_SIZE}" ]; then
        ceph ${CLI_OPTS} config-key set mgr/localpool/min_size ${LPOOL_MIN_SIZE}
    fi
fi

log "SUCCESS"
# start ceph-mgr
exec /usr/bin/ceph-mgr $DAEMON_OPTS -i "$MGR_NAME"

