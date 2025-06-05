#!/bin/bash

echo "🎯 ULTIMATE COVERAGE - Targeting Specific Uncovered Lines"
echo "========================================================"

pkill -f persistent_warehouse 2>/dev/null
sleep 1

echo "Phase 1: UDP/Datagram Path (Lines 931-956) - 25 potential lines"
echo "================================================================"

# Start server with UDP enabled
./persistent_warehouse -T 47000 -U 47001 -f ultimate_test1.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
PID1=$!
sleep 3

# Send UDP DELIVER commands (should hit handle_molecule_request lines 931-956)
echo "Testing UDP DELIVER commands..."
echo "DELIVER WATER 5" | nc -u -w2 localhost 47001 2>/dev/null
echo "DELIVER CARBON DIOXIDE 3" | nc -u -w2 localhost 47001 2>/dev/null
echo "DELIVER ALCOHOL 2" | nc -u -w2 localhost 47001 2>/dev/null
echo "DELIVER GLUCOSE 1" | nc -u -w2 localhost 47001 2>/dev/null

# Send malformed UDP commands (should hit error paths)
echo "DELIVER INVALID 1" | nc -u -w2 localhost 47001 2>/dev/null
echo "DELIVER WATER 0" | nc -u -w2 localhost 47001 2>/dev/null

kill $PID1 2>/dev/null
wait $PID1 2>/dev/null

echo ""
echo "Phase 2: UDS Datagram Path - Different socket handling"
echo "====================================================="

# Test UDS datagram (different from UDP)
./persistent_warehouse -s /tmp/ultimate_stream.sock -d /tmp/ultimate_dgram.sock -f ultimate_test2.dat -c 800 -o 800 -H 800 >/dev/null 2>&1 &
PID2=$!
sleep 3

# Wait for socket creation
for i in {1..15}; do
    if [ -S "/tmp/ultimate_dgram.sock" ]; then break; fi
    sleep 0.3
done

if [ -S "/tmp/ultimate_dgram.sock" ]; then
    echo "Testing UDS datagram commands..."
    echo "DELIVER WATER 3" | nc -U -u -w2 /tmp/ultimate_dgram.sock 2>/dev/null
    echo "DELIVER ALCOHOL 1" | nc -U -u -w2 /tmp/ultimate_dgram.sock 2>/dev/null
fi

kill $PID2 2>/dev/null
wait $PID2 2>/dev/null
rm -f /tmp/ultimate_*.sock

echo ""
echo "Phase 3: Force Error Conditions (Lines 168-170, 180-205, 216-218)"
echo "================================================================="

# Create corrupted save file to trigger error paths
echo "Creating corrupted save file..."
echo "corrupted_data_not_inventory_format" > corrupted_test.dat

# This should trigger the file validation error paths
timeout 3s ./persistent_warehouse -T 47010 -f corrupted_test.dat -c 100 -o 100 -H 100 2>/dev/null

# Try invalid file permissions (should hit error paths)
echo "Testing permission errors..."
touch readonly_test.dat
chmod 444 readonly_test.dat
timeout 3s ./persistent_warehouse -T 47020 -f readonly_test.dat -c 100 -o 100 -H 100 2>/dev/null
rm -f readonly_test.dat

echo ""
echo "Phase 4: Multiple Concurrent Connections (Force locking - Lines 262-293)"
echo "========================================================================"

# Start server for concurrent testing
./persistent_warehouse -T 47030 -f concurrent_test.dat -c 500 -o 500 -H 500 >/dev/null 2>&1 &
PID4=$!
sleep 2

# Launch multiple simultaneous connections to force locking
echo "Testing concurrent access..."
for i in {1..5}; do
    {
        echo "ADD CARBON 20"
        echo "ADD OXYGEN 15"
        echo "ADD HYDROGEN 25"
    } | nc localhost 47030 2>/dev/null &
done

sleep 3

# Send more commands to force lock contention
for i in {1..3}; do
    echo "ADD CARBON 10" | nc localhost 47030 2>/dev/null &
done

sleep 2
kill $PID4 2>/dev/null
wait $PID4 2>/dev/null

echo ""
echo "Phase 5: Admin Commands with High Quantities (Force min3 calls)"
echo "=============================================================="

# Test admin commands with large inventory to ensure min3 is called
{
    sleep 1
    echo "GEN SOFT DRINK"
    sleep 0.5
    echo "GEN VODKA"
    sleep 0.5  
    echo "GEN CHAMPAGNE"
    sleep 0.5
    echo "shutdown"
} | ./persistent_warehouse -T 47040 -f admin_test.dat -c 10000 -o 10000 -H 10000 2>/dev/null

echo ""
echo "Phase 6: Edge Cases and Error Conditions"
echo "======================================="

# Test maximum values and edge cases
./persistent_warehouse -T 47050 -f edge_test.dat -c 999999999999 -o 999999999999 -H 999999999999 >/dev/null 2>&1 &
PID6=$!
sleep 2

# Test commands with large amounts
echo "ADD CARBON 999999999999999999" | nc localhost 47050 2>/dev/null
echo "ADD OXYGEN 0" | nc localhost 47050 2>/dev/null

kill $PID6 2>/dev/null
wait $PID6 2>/dev/null

echo ""
echo "🔍 CHECKING COVERAGE IMPROVEMENT..."
echo "=================================="

gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed"

# Check specific functions that should now be covered
echo ""
echo "Checking specific function coverage:"
echo "min3 function:"
grep -A 2 -B 1 "min3.*{" persistent_warehouse.c.gcov | head -5

echo ""
echo "UDP handling:"
grep -A 5 "handle_molecule_request" persistent_warehouse.c.gcov | head -7

echo ""
echo "Locking functions:"
grep -A 3 "lock_inventory.*{" persistent_warehouse.c.gcov | head -5

# Cleanup
pkill -f persistent_warehouse 2>/dev/null
rm -f ultimate_test*.dat concurrent_test.dat admin_test.dat edge_test.dat corrupted_test.dat

echo ""
echo "✅ ULTIMATE COVERAGE TEST COMPLETE!"
echo "If coverage improved, we successfully hit new code paths!"