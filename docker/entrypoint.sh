#!/bin/sh

set -fue

_SLEEP_TIMER_M="${TEST_FREQUENCY_MINUTES:-"0"}"

while true;
do
  sleep "${_SLEEP_TIMER_M}m" &
  /runtime/monitor.py
  if [ "${_SLEEP_TIMER_M}" -gt 0 ];
  then
    wait
  else
    break
  fi
done
