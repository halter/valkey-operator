#!/bin/sh

set -e

VALKEY_ROLE="$(valkey-cli -c info replication 2>/dev/null | awk '/^role:/ { print $1 }' | tr -d '\r')"

if [ "${VALKEY_ROLE}" != "role:master" ]; then
	echo "ROLE IS NOT MASTER"
	exit 0
fi

CONNTECTED_SLAVES="$(valkey-cli -c info replication | awk -F: '/^connected_slaves:/ { print $2 }')"

if [ "$CONNTECTED_SLAVES" -le "0" ]; then
	echo "Connected slaves is 0, therefore nothing to do"
	exit 0
fi

SLAVE0="$(valkey-cli -c info replication | awk -F: '/^slave0:/ { print $2 }')"
SLAVE_IP="$(echo "${SLAVE0}" | tr , '\n' | awk -F= '/^ip/ { print $2 }')"
SLAVE_PORT="$(echo "${SLAVE0}" | tr , '\n' | awk -F= '/^port/ { print $2 }')"
SLAVE_STATUS="$(echo "${SLAVE0}" | tr , '\n' | awk -F= '/^state/ { print $2 }')"
if [ "${SLAVE_STATUS}" != "online" ]; then
	echo "Slave status is $SLAVE_STATUS, therefore nothing to do"
	exit 0
fi

echo "Pause writes"
valkey-cli -c CLIENT PAUSE "5000" WRITE

valkey-cli -h "${SLAVE_IP}" -p "${SLAVE_PORT}" -c cluster failover
sleep 3s
