#!/bin/bash

# q6_server_coverage.sh - Server Coverage Script (FIXED)
# Simple and effective server testing without hanging

echo "🚀 Q6 SERVER COVERAGE SCRIPT"
echo "============================"

# Kill any existing servers
pkill -f persistent_warehouse 2>/dev/null
sleep 1

# Build
echo "Building server..."
make clean >/dev/null 2>&1
make persistent_warehouse || exit 1

echo ""
echo "📋 Phase 1: Argument Errors"
# Test all argument parsing errors quickly
timeout 1s ./persistent_warehouse 2>&1 | head -2
timeout 1s ./persistent_warehouse --help 2>&1 | head -2
timeout 1s ./persistent_warehouse -T 0 -f test.dat 2>&1 | head -2
timeout 1s ./persistent_warehouse -T 99999 -f test.dat 2>&1 | head -2
timeout 1s ./persistent_warehouse -T 12345 -U 12345 -f test.dat 2>&1 | head -2
timeout 1s ./persistent_warehouse -T 12345 2>&1 | head -2
timeout 1s ./persistent_warehouse -f test.dat 2>&1 | head -2

echo ""
echo "📋 Phase 2: File Operations"
# Test file creation
rm -f test_new.dat
timeout 3s ./persistent_warehouse -T 40001 -f test_new.dat -c 100 -o 200 -H 300 >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

# Test loading existing file
timeout 3s ./persistent_warehouse -T 40002 -f test_new.dat >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

# Test corrupted file
echo "corrupted" > corrupted.dat
timeout 3s ./persistent_warehouse -T 40003 -f corrupted.dat >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo ""
echo "📋 Phase 3: Network Commands"
# Start server and test commands
./persistent_warehouse -T 40010 -U 40011 -f network_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Test ADD commands
echo "ADD CARBON 500" | nc -w1 localhost 40010 2>/dev/null
echo "ADD OXYGEN 750" | nc -w1 localhost 40010 2>/dev/null
echo "ADD HYDROGEN 1200" | nc -w1 localhost 40010 2>/dev/null
echo "ADD INVALID 100" | nc -w1 localhost 40010 2>/dev/null
echo "ADD CARBON 999999999999999999999" | nc -w1 localhost 40010 2>/dev/null

# Test DELIVER commands
echo "DELIVER WATER 10" | nc -u -w1 localhost 40011 2>/dev/null
echo "DELIVER CARBON DIOXIDE 5" | nc -u -w1 localhost 40011 2>/dev/null
echo "DELIVER ALCOHOL 3" | nc -u -w1 localhost 40011 2>/dev/null
echo "DELIVER GLUCOSE 2" | nc -u -w1 localhost 40011 2>/dev/null
echo "DELIVER INVALID 1" | nc -u -w1 localhost 40011 2>/dev/null
echo "DELIVER WATER 999999999999999999999" | nc -u -w1 localhost 40011 2>/dev/null

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 4: UDS Mode"
# Test UDS
rm -f /tmp/test_stream.sock /tmp/test_dgram.sock
./persistent_warehouse -s /tmp/test_stream.sock -d /tmp/test_dgram.sock -f uds_test.dat >/dev/null 2>&1 &
UDS_PID=$!
sleep 2

if [ -S "/tmp/test_stream.sock" ]; then
    echo "ADD CARBON 200" | nc -U /tmp/test_stream.sock 2>/dev/null
    echo "ADD OXYGEN 300" | nc -U /tmp/test_stream.sock 2>/dev/null
fi

kill $UDS_PID 2>/dev/null
wait $UDS_PID 2>/dev/null

echo ""
echo "📋 Phase 5: Timeout Test"
# Test timeout
timeout 5s ./persistent_warehouse -T 40020 -f timeout_test.dat -t 2 >/dev/null 2>&1

echo ""
echo "📋 Phase 6: Admin Commands"
# Test admin commands with proper stdin
{
    sleep 1
    echo "GEN SOFT DRINK"
    echo "GEN VODKA"
    echo "GEN CHAMPAGNE"
    echo "shutdown"
} | timeout 5s ./persistent_warehouse -T 40030 -f admin_test.dat -c 100 -o 100 -H 100 >/dev/null 2>&1

echo ""
echo "📋 Phase 7: Concurrent Access"
# Test concurrent servers with same file
./persistent_warehouse -T 40040 -f concurrent.dat >/dev/null 2>&1 &
PID1=$!
sleep 1

./persistent_warehouse -T 40041 -f concurrent.dat >/dev/null 2>&1 &
PID2=$!
sleep 1

kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null

echo ""
echo "📊 Generating Coverage"
gcov persistent_warehouse.c 2>/dev/null || true

if [ -f "persistent_warehouse.c.gcov" ]; then
    SERVER_COV=$(gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "Server coverage: $SERVER_COV"
    UNCOVERED=$(grep -c "#####:" persistent_warehouse.c.gcov || echo "0")
    echo "Uncovered lines: $UNCOVERED"
else
    echo "No coverage data!"
fi

# Cleanup
pkill -f persistent_warehouse 2>/dev/null
rm -f test_new.dat corrupted.dat network_test.dat uds_test.dat timeout_test.dat admin_test.dat concurrent.dat
rm -f /tmp/test_*.sock

echo ""
echo "✅ Server coverage complete!"