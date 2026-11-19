#!/bin/sh
# Runs an online match between two copies of the game on this computer and
# checks both ended with the same scores.
#   GODOT=/path/to/godot tests/run_net_test.sh          (by address)
#   GODOT=/path/to/godot tests/run_net_test.sh steam    (over a stand-in for Steam)
GODOT=${GODOT:-godot}
MODE=${1:-address}
cd "$(dirname "$0")/.."
"$GODOT" --headless --fixed-fps 120 --script res://tests/net_host.gd -- $MODE > /tmp/marbles_host.log 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --fixed-fps 120 --script res://tests/net_client.gd -- $MODE > /tmp/marbles_client.log 2>&1
CLIENT=$?
wait $HOST
HOSTRC=$?
grep -E "^(HOST|CLIENT)" /tmp/marbles_host.log /tmp/marbles_client.log | sed 's/^[^:]*://'
grep -h "SCRIPT ERROR" -A2 /tmp/marbles_host.log /tmp/marbles_client.log | head -20
H=$(grep -E "^HOST frame [12] " /tmp/marbles_host.log)
C=$(grep -E "^CLIENT frame [12] " /tmp/marbles_client.log | sed 's/^CLIENT/HOST/')
if [ "$H" = "$C" ] && [ -n "$H" ]; then echo "PASS  client and host agree on scores and pieces"; else echo "FAIL  client and host disagree"; exit 1; fi
[ $CLIENT -eq 0 ] && [ $HOSTRC -eq 0 ]
