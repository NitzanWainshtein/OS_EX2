#!/bin/bash

# q6_client_coverage.sh - Client Coverage Script (FIXED)
# Simple and effective client testing without hanging

echo "🚀 Q6 CLIENT COVERAGE SCRIPT"
echo "============================"

# Kill any existing processes
pkill -f persistent_requester 2>/dev/null
pkill -f persistent_warehouse 2>/dev/null
sleep 1

# Build
echo "Building client..."
make persistent_requester || exit 1

echo ""
echo "📋 Phase 1: Argument Errors"
# Test argument parsing errors
timeout 1s ./persistent_requester 2>&1 | head -2
timeout 1s ./persistent_requester --help 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost 2>&1 | head -2
timeout 1s ./persistent_requester -p 12345 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 0 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 99999 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 12345 -u 12345 2>&1 | head -2
timeout 1s ./persistent_requester -f /invalid/path.sock 2>&1 | head -2

echo ""
echo "📋 Phase 2: Connection Failures"
# Test connection failures
timeout 2s ./persistent_requester -h invalid.host -p 12345 2>&1 | head -3
timeout 2s ./persistent_requester -h 127.0.0.1 -p 1 2>&1 | head -3
timeout 2s ./persistent_requester -f /tmp/nonexistent.sock 2>&1 | head -3

echo ""
echo "📋 Phase 3: Starting Test Server"
# Start a test server
./persistent_warehouse -T 41000 -U 41001 -f client_test.dat -c 10000 -o 10000 -H 10000 >/dev/null 2>&1 &
SERVER_PID=$!

# Wait for server
echo "Waiting for server..."
for i in {1..10}; do
    if nc -z localhost 41000 2>/dev/null; then
        echo "Server ready!"
        break
    fi
    sleep 0.5
done

echo ""
echo "📋 Phase 4: Full Menu Test"
# Test complete menu navigation
{
    echo "invalid"      # Invalid main menu
    echo "1"           # Add atoms
    echo "invalid"     # Invalid atom menu
    echo "1"           # CARBON
    echo "invalid"     # Invalid amount
    echo "0"           # Zero amount
    echo "999999999999999999999"  # Too large
    echo "100"         # Valid amount
    echo "2"           # OXYGEN
    echo "200"
    echo "3"           # HYDROGEN
    echo "300"
    echo "4"           # Back
    echo "2"           # Request molecules
    echo "1"           # WATER
    echo "5"
    echo "2"           # CARBON DIOXIDE
    echo "3"
    echo "3"           # ALCOHOL
    echo "2"
    echo "4"           # GLUCOSE
    echo "1"
    echo "5"           # Back
    echo "3"           # Quit
} | timeout 10s ./persistent_requester -h localhost -p 41000 -u 41001 >/dev/null 2>&1

echo ""
echo "📋 Phase 5: TCP-Only Test"
# Test without UDP
{
    echo "1"           # Add atoms
    echo "1"           # CARBON
    echo "50"
    echo "4"           # Back
    echo "2"           # Try molecules (should fail)
    echo "3"           # Quit
} | timeout 5s ./persistent_requester -h localhost -p 41000 >/dev/null 2>&1

echo ""
echo "📋 Phase 6: Edge Cases"
# Test edge cases
{
    echo "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    echo "1"
    echo "1"
    echo "1000000000000000000"  # Max valid
    echo "4"
    echo "3"
} | timeout 5s ./persistent_requester -h localhost -p 41000 -u 41001 >/dev/null 2>&1

echo ""
echo "📋 Phase 7: Hostname Tests"
# Test with IP
{
    echo "3"
} | timeout 3s ./persistent_requester -h 127.0.0.1 -p 41000 >/dev/null 2>&1

# Test with localhost
{
    echo "3"
} | timeout 3s ./persistent_requester -h localhost -p 41000 >/dev/null 2>&1

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 8: UDS Test"
# Start UDS server
rm -f /tmp/client_test_stream.sock /tmp/client_test_dgram.sock
./persistent_warehouse -s /tmp/client_test_stream.sock -d /tmp/client_test_dgram.sock -f uds_client_test.dat >/dev/null 2>&1 &
UDS_PID=$!

# Wait for socket
for i in {1..10}; do
    if [ -S "/tmp/client_test_stream.sock" ]; then
        break
    fi
    sleep 0.5
done

if [ -S "/tmp/client_test_stream.sock" ]; then
    echo "Testing UDS client..."
    {
        echo "1"       # Add atoms
        echo "1"       # CARBON
        echo "150"
        echo "4"       # Back
        echo "2"       # Request molecules
        echo "1"       # WATER
        echo "10"
        echo "5"       # Back
        echo "3"       # Quit
    } | timeout 5s ./persistent_requester -f /tmp/client_test_stream.sock -d /tmp/client_test_dgram.sock >/dev/null 2>&1
    
    # Test stream only
    {
        echo "1"
        echo "1"
        echo "75"
        echo "4"
        echo "2"       # Should show not available
        echo "3"
    } | timeout 5s ./persistent_requester -f /tmp/client_test_stream.sock >/dev/null 2>&1
fi

kill $UDS_PID 2>/dev/null
wait $UDS_PID 2>/dev/null

echo ""
echo "📋 Phase 9: Disconnection Test"
# Test server disconnection
./persistent_warehouse -T 41010 -f disconnect_test.dat >/dev/null 2>&1 &
DISC_PID=$!
sleep 1

{
    echo "1"
    echo "1"
    echo "50"
    sleep 2
    # Server will be killed here
    echo "2"
    echo "100"
    echo "4"
    echo "3"
} | timeout 5s ./persistent_requester -h localhost -p 41010 >/dev/null 2>&1 &
CLIENT_PID=$!

sleep 1
kill $DISC_PID 2>/dev/null
wait $CLIENT_PID 2>/dev/null

echo ""
echo "📊 Generating Coverage"
gcov persistent_requester.c 2>/dev/null || true

if [ -f "persistent_requester.c.gcov" ]; then
    CLIENT_COV=$(gcov persistent_requester.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "Client coverage: $CLIENT_COV"
    UNCOVERED=$(grep -c "#####:" persistent_requester.c.gcov || echo "0")
    echo "Uncovered lines: $UNCOVERED"
else
    echo "No coverage data!"
fi

# Cleanup
pkill -f persistent_requester 2>/dev/null
pkill -f persistent_warehouse 2>/dev/null
rm -f client_test.dat uds_client_test.dat disconnect_test.dat
rm -f /tmp/client_test_*.sock

echo ""
echo "✅ Client coverage complete!"