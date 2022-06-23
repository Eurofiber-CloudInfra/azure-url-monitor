#!/bin/sh

set -fue

_SLEEP_TIMER_M="${TEST_FREQUENCY_MINUTES:-"0"}"
_CMD_OPTS=""
if [ -n "${DEBUG}" ] && [ "${DEBUG}" = "YES" ];
then
  _CMD_OPTS="${_CMD_OPTS} -vvvv"
fi

while true;
do
  sleep "${_SLEEP_TIMER_M}m" &
  /runtime/monitor.py $_CMD_OPTS
  if [ "${_SLEEP_TIMER_M}" -gt 0 ];
  then
    wait
  else
    break
  fi
done
