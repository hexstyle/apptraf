#!/usr/bin/env bash
# Reproduce every number from the README "Resource footprint" table
# on your own machine. Run after the daemon has been up for a few minutes.

set -e

DPID=$(pgrep -f '/opt/homebrew/opt/apptraf/bin/apptrafd' | head -1)
if [ -z "$DPID" ]; then
    echo "apptrafd is not running."
    echo "Start it with:  brew services start hexstyle/apptraf/apptraf"
    exit 1
fi

DB="$HOME/Library/Application Support/AppTraf/data.sqlite"

echo "=== daemon process ==="
ps -p "$DPID" -o pid,rss,%cpu,etime,command | sed -n '1p;$p'
echo "RSS is in kilobytes."
echo

echo "=== disk usage (after WAL checkpoint) ==="
sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);" > /dev/null
du -h "$DB"* 2>/dev/null | sort -h
echo

echo "=== data in DB ==="
sqlite3 -separator $'\n' "$DB" "
  SELECT 'rows in samples:  ' || COUNT(*)             FROM samples;
  SELECT 'distinct apps:    ' || COUNT(DISTINCT app)  FROM samples;
  SELECT 'hours covered:    ' || COUNT(DISTINCT hour) FROM samples;
  SELECT 'process_state:    ' || COUNT(*)             FROM process_state;
"
echo

echo "=== sample latency (3 runs) ==="
for i in 1 2 3; do
    { /usr/bin/time -p nettop -P -L 1 -J bytes_in,bytes_out -x > /dev/null; } 2> /tmp/.apptraf-bench.tmp
    grep real /tmp/.apptraf-bench.tmp | awk -v n="$i" '{print "  run "n": "$2"s"}'
done
rm -f /tmp/.apptraf-bench.tmp
echo

echo "=== top 5 apps over last 24 h ==="
NOW_HOUR=$(($(date +%s) / 3600 * 3600))
FROM_HOUR=$((NOW_HOUR - 23 * 3600))
sqlite3 -header -column "$DB" "
  SELECT app, SUM(bytes_in) AS in_b, SUM(bytes_out) AS out_b,
         SUM(bytes_in) + SUM(bytes_out) AS total
  FROM samples WHERE hour >= $FROM_HOUR
  GROUP BY app
  ORDER BY total DESC LIMIT 5;
"
