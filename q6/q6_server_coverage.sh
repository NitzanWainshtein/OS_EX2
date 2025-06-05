#!/bin/bash

# q6_server_coverage.sh - Enhanced Server Coverage Script (TARGETS SPECIFIC UNCOVERED LINES)
# Comprehensive server testing to hit ALL uncovered lines shown in analysis

echo "🚀 Q6 ENHANCED SERVER COVERAGE SCRIPT"
echo "====================================="

# Kill any existing servers but preserve coverage data
pkill -f persistent_warehouse 2>/dev/null
sleep 1

# Build ONLY if needed AND no coverage data exists
echo "Building server (preserving coverage data)..."
if [ -f "persistent_warehouse.gcda" ]; then
    echo "Coverage data exists - preserving, no rebuild"
elif [ ! -f "persistent_warehouse" ]; then
    make persistent_warehouse || exit 1
else
    echo "Binary exists, skipping build to preserve coverage data"
fi

echo ""
echo "📋 Phase 1: MIN3 FUNCTION TESTING (Lines 106-108)"
# Start server that will use min3 function for drink calculations
./persistent_warehouse -T 40005 -f min3_test.dat -c 10000 -o 10000 -H 10000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

# Send admin commands that trigger min3 function (lines 516, 522, 528)
{
    sleep 1
    echo "GEN SOFT DRINK"      # Triggers min3(water, co2, alcohol) - line 516
    sleep 0.5
    echo "GEN VODKA"           # Triggers min3(water, alcohol, glucose) - line 522  
    sleep 0.5
    echo "GEN CHAMPAGNE"       # Triggers min3(water, co2, glucose) - line 528
    sleep 0.5
    echo "shutdown"
} | timeout 8s ./persistent_warehouse -T 40006 -f min3_test2.dat -c 10000 -o 10000 -H 10000 >/dev/null 2>&1

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 2: FILE I/O ERROR PATHS (Lines 168-170, 180-205, 216-218, 233)"

# Test write failure scenarios (lines 168-170)
mkdir -p /tmp/readonly_test 2>/dev/null
chmod 555 /tmp/readonly_test 2>/dev/null
timeout 3s ./persistent_warehouse -T 40010 -f /tmp/readonly_test/readonly.dat -c 100 >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null
chmod 755 /tmp/readonly_test 2>/dev/null
rmdir /tmp/readonly_test 2>/dev/null

# Test corrupted file - wrong size (lines 180-191)
echo "wrong_size_file" > corrupted_size.dat
timeout 3s ./persistent_warehouse -T 40011 -f corrupted_size.dat >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

# Test corrupted file - wrong magic (lines 194-205)
printf '\x00\x00\x00\x00\x00\x00\x00\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF\x11' > bad_magic.dat
printf '\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x03' >> bad_magic.dat
timeout 3s ./persistent_warehouse -T 40012 -f bad_magic.dat >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

# Test mmap failure scenario (lines 216-218) - harder to trigger but try with /dev/full
timeout 3s ./persistent_warehouse -T 40013 -f /dev/full >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null
wait $PID 2>/dev/null

echo ""
echo "📋 Phase 3: LOCKING FUNCTIONS (Lines 262-274, 281-293)"
# Create multiple server instances to trigger file locking
./persistent_warehouse -T 40020 -f lock_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
PID1=$!
sleep 1

# Try to start another server with same file to trigger locking
timeout 3s ./persistent_warehouse -T 40021 -f lock_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
PID2=$!
sleep 1

# Send commands to both to trigger lock/unlock functions
echo "ADD CARBON 100" | nc -w1 localhost 40020 2>/dev/null
echo "ADD OXYGEN 100" | nc -w1 localhost 40020 2>/dev/null

kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null

echo ""
echo "📋 Phase 4: COMMAND PROCESSING (Lines 306-398)"
# Start server for comprehensive command testing
./persistent_warehouse -T 40030 -U 40031 -f command_test.dat -c 1000000000000000000 -o 1000000000000000000 -H 1000000000000000000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

# Test amount overflow scenarios (lines 324-326, 335-337, 346-348)
echo "ADD CARBON 1000000000000000000" | nc -w1 localhost 40030 2>/dev/null
echo "ADD OXYGEN 1000000000000000000" | nc -w1 localhost 40030 2>/dev/null
echo "ADD HYDROGEN 1000000000000000000" | nc -w1 localhost 40030 2>/dev/null

# Test amount too large (lines 311-314)
echo "ADD CARBON 18446744073709551615" | nc -w1 localhost 40030 2>/dev/null
echo "ADD OXYGEN 18446744073709551000" | nc -w1 localhost 40030 2>/dev/null
echo "ADD HYDROGEN 99999999999999999999" | nc -w1 localhost 40030 2>/dev/null

# Test unknown atom types (lines 357-358)
echo "ADD INVALID 100" | nc -w1 localhost 40030 2>/dev/null
echo "ADD PLUTONIUM 50" | nc -w1 localhost 40030 2>/dev/null
echo "ADD NITROGEN 25" | nc -w1 localhost 40030 2>/dev/null

# Test invalid command formats (lines 390-391)
echo "INVALID COMMAND" | nc -w1 localhost 40030 2>/dev/null
echo "ADD" | nc -w1 localhost 40030 2>/dev/null
echo "ADD CARBON" | nc -w1 localhost 40030 2>/dev/null
echo "RANDOM TEXT" | nc -w1 localhost 40030 2>/dev/null

# Test successful operations to hit success paths (lines 328-332, 339-343, 350-354, 361-387)
echo "ADD CARBON 500" | nc -w1 localhost 40030 2>/dev/null
echo "ADD OXYGEN 750" | nc -w1 localhost 40030 2>/dev/null
echo "ADD HYDROGEN 1200" | nc -w1 localhost 40030 2>/dev/null

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 5: MOLECULE DELIVERY COMPREHENSIVE (Lines 413-624)"
# Start server with specific inventory for molecule testing
./persistent_warehouse -T 40040 -U 40041 -f molecule_test.dat -c 20000 -o 20000 -H 20000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

# Test ALL molecule types to hit can_deliver function (lines 416-446)
echo "DELIVER WATER 100" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER CARBON DIOXIDE 50" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER ALCOHOL 30" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER GLUCOSE 20" | nc -u -w1 localhost 40041 2>/dev/null

# Test unknown molecule (line 431)
echo "DELIVER METHANE 10" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER INVALID 5" | nc -u -w1 localhost 40041 2>/dev/null

# Test invalid quantities (lines 577-582)
echo "DELIVER WATER 0" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER WATER 18446744073709551615" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER OXYGEN 99999999999999999999" | nc -u -w1 localhost 40041 2>/dev/null

# Test insufficient atoms scenario (lines 617-619, 445-446)
echo "DELIVER GLUCOSE 50000" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER ALCOHOL 10000" | nc -u -w1 localhost 40041 2>/dev/null

# Test CARBON DIOXIDE parsing (lines 562-568)
echo "DELIVER CARBON DIOXIDE 10" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER CARBON DIOXIDE" | nc -u -w1 localhost 40041 2>/dev/null

# Test successful deliveries with status reporting (lines 585-615)
echo "DELIVER WATER 1" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER WATER 5" | nc -u -w1 localhost 40041 2>/dev/null

# Test invalid DELIVER commands (lines 622-624)
echo "DELIVER" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER WATER" | nc -u -w1 localhost 40041 2>/dev/null
echo "DELIVER INVALID FORMAT" | nc -u -w1 localhost 40041 2>/dev/null
echo "RANDOM REQUEST" | nc -u -w1 localhost 40041 2>/dev/null

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 6: CALCULATE_POSSIBLE_MOLECULES (Lines 459-498)"
# Test molecule calculation function through admin commands
{
    sleep 1
    echo "GEN SOFT DRINK"      # Lines 515-517
    sleep 0.5
    echo "GEN VODKA"           # Lines 521-523
    sleep 0.5  
    echo "GEN CHAMPAGNE"       # Lines 527-529
    sleep 0.5
    echo "INVALID ADMIN CMD"   # Lines 534-535
    sleep 0.5
    echo "shutdown"            # Line 532
} | timeout 8s ./persistent_warehouse -T 40050 -f admin_calc_test.dat -c 30000 -o 30000 -H 30000 >/dev/null 2>&1

echo ""
echo "📋 Phase 7: NETWORK SOCKET ERRORS (Lines 793-794, 802-817)"
# Test TCP listen failure by binding to used port
./persistent_warehouse -T 40060 -f socket_test1.dat >/dev/null 2>&1 &
PID1=$!
sleep 1

# Try to bind to same TCP port (should fail at bind or listen)
timeout 3s ./persistent_warehouse -T 40060 -f socket_test2.dat >/dev/null 2>&1

# Test UDP socket creation and binding
./persistent_warehouse -T 40061 -U 40061 -f socket_test3.dat >/dev/null 2>&1 &
PID2=$!
sleep 1

# Try to bind to same UDP port
timeout 3s ./persistent_warehouse -T 40062 -U 40061 -f socket_test4.dat >/dev/null 2>&1

kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null

echo ""
echo "📋 Phase 8: UDS SOCKET ERRORS (Lines 832-836, 855, 1000-1005)"
# Test UDS socket failures
timeout 3s ./persistent_warehouse -s /invalid/path.sock -f uds_test.dat >/dev/null 2>&1
timeout 3s ./persistent_warehouse -d /invalid/path.sock -f uds_test2.dat >/dev/null 2>&1

# Test UDS listen failure with existing socket
touch /tmp/existing.sock
timeout 3s ./persistent_warehouse -s /tmp/existing.sock -f uds_test3.dat >/dev/null 2>&1
rm -f /tmp/existing.sock

echo ""
echo "📋 Phase 9: CONNECTION HANDLING (Lines 873-989)"
# Test timeout functionality (lines 873-874)
timeout 6s ./persistent_warehouse -T 40070 -f timeout_test.dat -t 2 >/dev/null 2>&1

# Test select error and connection handling
./persistent_warehouse -T 40080 -f connection_test.dat >/dev/null 2>&1 &
CONN_PID=$!
sleep 2

# Test multiple client connections and disconnections (lines 890-989)
for i in {1..3}; do
    {
        echo "ADD CARBON 10"
        sleep 0.5
    } | timeout 3s nc localhost 40080 >/dev/null 2>&1 &
done

# Test client disconnect scenarios (lines 981-985)
{
    echo "ADD CARBON 50"
    # Client will disconnect here
} | timeout 2s nc localhost 40080 >/dev/null 2>&1 &

sleep 1

# Test admin shutdown command (lines 962-971) 
{
    sleep 1
    echo "shutdown"
} | timeout 5s ./persistent_warehouse -T 40090 -f shutdown_test.dat >/dev/null 2>&1 &

sleep 2
kill $CONN_PID 2>/dev/null
wait $CONN_PID 2>/dev/null

echo ""
echo "📋 Phase 10: UDP/UDS DATAGRAM HANDLING (Lines 935-956) - FIXED"
# Start server with UDP and UDS datagram
./persistent_warehouse -T 40100 -U 40101 -s /tmp/test_stream.sock -d /tmp/test_dgram.sock -f datagram_test.dat -c 5000 -o 5000 -H 5000 >/dev/null 2>&1 &
DGRAM_PID=$!
sleep 2

# Test UDP datagram handling (lines 935-945)
echo "DELIVER WATER 5" | nc -u -w1 localhost 40101 2>/dev/null
echo "DELIVER INVALID 1" | nc -u -w1 localhost 40101 2>/dev/null

# Test UDS datagram handling (lines 948-956) - FIXED VERSION
if [ -S "/tmp/test_dgram.sock" ]; then
    echo "Testing UDS datagram socket..."
    
    # Method 1: Try with socat if available
    if command -v socat >/dev/null 2>&1; then
        timeout 2s bash -c 'echo "DELIVER CARBON DIOXIDE 3" | socat - UNIX-SENDTO:/tmp/test_dgram.sock' 2>/dev/null || true
        timeout 2s bash -c 'echo "DELIVER ALCOHOL 2" | socat - UNIX-SENDTO:/tmp/test_dgram.sock' 2>/dev/null || true
    else
        # Method 2: Use a simple C program or skip
        echo "UDS datagram testing skipped (socat not available)"
    fi
fi

# Kill server immediately to prevent hanging
sleep 1
kill $DGRAM_PID 2>/dev/null
wait $DGRAM_PID 2>/dev/null
rm -f /tmp/test_stream.sock /tmp/test_dgram.sock

echo ""
echo "📊 Generating Coverage (accumulative)"
gcov persistent_warehouse.c 2>/dev/null || true

if [ -f "persistent_warehouse.c.gcov" ]; then
    SERVER_COV=$(gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "Server coverage: $SERVER_COV"
    UNCOVERED=$(grep -c "#####:" persistent_warehouse.c.gcov || echo "0")
    echo "Uncovered lines: $UNCOVERED"
    
    echo "Specifically targeted uncovered lines still remaining:"
    grep -n "#####:" persistent_warehouse.c.gcov | grep -E "(106|107|108|168|169|170|180|181|182|188|189|190|191|194|195|196|202|203|204|205|216|217|218|233|262|263|265|266|267|268|270|271|274|281|282|284|285|286|287|289|290|293)" | head -10
else
    echo "No coverage data!"
fi

# Cleanup files but preserve coverage data
rm -f min3_test.dat min3_test2.dat corrupted_size.dat bad_magic.dat lock_test.dat command_test.dat molecule_test.dat admin_calc_test.dat socket_test*.dat uds_test*.dat timeout_test.dat connection_test.dat shutdown_test.dat datagram_test.dat

echo ""
echo "✅ Enhanced server coverage complete!"