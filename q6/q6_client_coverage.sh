#!/bin/bash

# q6_client_coverage.sh - Enhanced Client Coverage Script (TARGETS SPECIFIC UNCOVERED LINES)
# Comprehensive client testing to hit ALL specific uncovered lines from analysis

echo "🚀 Q6 ENHANCED CLIENT COVERAGE SCRIPT"
echo "====================================="

# Kill any existing processes
pkill -f persistent_requester 2>/dev/null
pkill -f persistent_warehouse 2>/dev/null
sleep 1

# Build ONLY if needed AND no coverage data exists
echo "Building client (preserving coverage data)..."
if [ -f "persistent_requester.gcda" ]; then
    echo "Coverage data exists - preserving, no rebuild"
elif [ ! -f "persistent_requester" ]; then
    make persistent_requester || exit 1
else
    echo "Binary exists, skipping build to preserve coverage data"
fi

echo ""
echo "📋 Phase 1: ARGUMENT ERROR RETURNS (Lines 81, 90)"
# Test specific argument parsing that returns 0
timeout 1s ./persistent_requester -h localhost 2>&1 | head -2
timeout 1s ./persistent_requester -p 12345 2>&1 | head -2
timeout 1s ./persistent_requester -u 12346 2>&1 | head -2
timeout 1s ./persistent_requester -f /tmp/socket.sock 2>&1 | head -2
timeout 1s ./persistent_requester -d /tmp/dgram.sock 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 0 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 99999 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p invalid 2>&1 | head -2
timeout 1s ./persistent_requester -u 0 -h localhost -p 12345 2>&1 | head -2
timeout 1s ./persistent_requester -u 99999 -h localhost -p 12345 2>&1 | head -2
timeout 1s ./persistent_requester -u invalid -h localhost -p 12345 2>&1 | head -2
timeout 1s ./persistent_requester -h localhost -p 12345 -u 12345 2>&1 | head -2

echo ""
echo "📋 Phase 2: HOSTNAME RESOLUTION (Lines 113-114, 119)"
# Start server for hostname testing
./persistent_warehouse -T 41000 -U 41001 -f hostname_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

# Test inet_aton success path (lines 113-114) with IP address
echo "Testing inet_aton success path (lines 113-114)..."
{
    echo "3"  # Quick quit
} | timeout 3s ./persistent_requester -h "192.168.1.1" -p 41000 >/dev/null 2>&1

{
    echo "3"  # Quick quit
} | timeout 3s ./persistent_requester -h "127.0.0.1" -p 41000 >/dev/null 2>&1

# Test gethostbyname failure path (line 119) with invalid hostname
echo "Testing gethostbyname failure path (line 119)..."
timeout 3s ./persistent_requester -h "definitely.invalid.hostname.nowhere.test.invalid" -p 41000 >/dev/null 2>&1
timeout 3s ./persistent_requester -h "nonexistent.domain.invalid" -p 41000 >/dev/null 2>&1

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 3: SOCKET CREATION FAILURES (Lines 247-248, 278-280, 291-292)"
# Method 1: Exhaust file descriptors
echo "Testing socket creation failures..."

(
    # Open many descriptors and set low limit
    exec 3< /dev/null 4< /dev/null 5< /dev/null 6< /dev/null 7< /dev/null
    exec 8< /dev/null 9< /dev/null 10< /dev/null 11< /dev/null 12< /dev/null
    exec 13< /dev/null 14< /dev/null 15< /dev/null 16< /dev/null 17< /dev/null
    
    ulimit -n 10 2>/dev/null
    
    # Try to create clients - should hit socket creation failures
    timeout 2s ./persistent_requester -h localhost -p 12345 2>/dev/null
    timeout 2s ./persistent_requester -h localhost -p 12345 -u 12346 2>/dev/null
    timeout 2s ./persistent_requester -f /tmp/test.sock 2>/dev/null
    timeout 2s ./persistent_requester -f /tmp/test.sock -d /tmp/dgram.sock 2>/dev/null
) 2>/dev/null

# Method 2: Try with invalid socket creation scenarios
timeout 2s ./persistent_requester -h localhost -p 1 2>/dev/null
timeout 2s ./persistent_requester -f /invalid/path.sock 2>/dev/null

echo ""
echo "📋 Phase 4: UDS DATAGRAM TESTING (Lines 310-318)"
# Create UDS server with datagram support
rm -f /tmp/client_stream.sock /tmp/client_dgram.sock

./persistent_warehouse -s /tmp/client_stream.sock -d /tmp/client_dgram.sock -f uds_dgram_test.dat -c 10000 -o 10000 -H 10000 >/dev/null 2>&1 &
UDS_PID=$!

# Wait for sockets
for i in {1..15}; do
    if [ -S "/tmp/client_stream.sock" ] && [ -S "/tmp/client_dgram.sock" ]; then
        break
    fi
    sleep 0.3
done

if [ -S "/tmp/client_stream.sock" ] && [ -S "/tmp/client_dgram.sock" ]; then
    echo "Testing UDS datagram socket creation and usage (lines 310-318)..."
    
    # Test that creates UDS datagram socket (lines 310-317)
    {
        echo "1"           # Add atoms
        echo "1"           # CARBON
        echo "500"         # Amount
        echo "2"           # OXYGEN
        echo "500"         # Amount
        echo "3"           # HYDROGEN
        echo "1000"        # Amount
        echo "4"           # Back
        echo "2"           # Request molecules (uses datagram)
        echo "1"           # WATER
        echo "10"          # Quantity
        echo "2"           # CARBON DIOXIDE
        echo "5"           # Quantity
        echo "5"           # Back
        echo "3"           # Quit
    } | timeout 10s ./persistent_requester -f /tmp/client_stream.sock -d /tmp/client_dgram.sock >/dev/null 2>&1
    
    # Test multiple datagram operations
    {
        echo "2"           # Request molecules
        echo "3"           # ALCOHOL
        echo "3"           # Quantity
        echo "4"           # GLUCOSE
        echo "2"           # Quantity
        echo "5"           # Back
        echo "3"           # Quit
    } | timeout 8s ./persistent_requester -f /tmp/client_stream.sock -d /tmp/client_dgram.sock >/dev/null 2>&1
fi

kill $UDS_PID 2>/dev/null
wait $UDS_PID 2>/dev/null
rm -f /tmp/client_stream.sock /tmp/client_dgram.sock

echo ""
echo "📋 Phase 5: CONNECTION ERROR HANDLING (Lines 378-380, 389, 398-400, 405-408)"
# Start server for connection error testing
./persistent_warehouse -T 41010 -U 41011 -f connection_error_test.dat -c 5000 -o 5000 -H 5000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

echo "Testing connection error scenarios..."

# Test stream send failure (line 378-380)
{
    echo "1"               # Add atoms
    echo "1"               # CARBON
    echo "100"             # Amount
    sleep 1               # Give time for connection
    # Server will be killed during operation
} | timeout 5s ./persistent_requester -h localhost -p 41010 -u 41011 >/dev/null 2>&1 &
CLIENT_PID=$!

# Kill server while client is sending to trigger send failure
sleep 1
kill $SERVER_PID 2>/dev/null

# Wait for client to handle the error
wait $CLIENT_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

# Test receive error scenarios (lines 389, 405-408)
./persistent_warehouse -T 41020 -f recv_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
SERVER_PID2=$!
sleep 2

{
    echo "1"               # Add atoms
    echo "1"               # CARBON
    echo "50"              # Amount
    # Connection will be disrupted
} | timeout 5s ./persistent_requester -h localhost -p 41020 >/dev/null 2>&1 &
CLIENT_PID2=$!

sleep 1
kill $SERVER_PID2 2>/dev/null  # Kill server to trigger receive errors
wait $CLIENT_PID2 2>/dev/null
wait $SERVER_PID2 2>/dev/null

echo ""
echo "📋 Phase 6: UDP ERROR SCENARIOS (Lines 471-472, 480)"
# Start server for UDP error testing
./persistent_warehouse -T 41030 -U 41031 -f udp_error_test.dat -c 2000 -o 2000 -H 2000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

echo "Testing UDP error scenarios..."

# Test UDP send/receive failures
{
    echo "2"               # Request molecules (UDP)
    echo "1"               # WATER
    echo "50"              # Quantity
    echo "5"               # Back
    echo "3"               # Quit
} | timeout 5s ./persistent_requester -h localhost -p 41030 -u 41031 >/dev/null 2>&1 &
CLIENT_PID=$!

# Kill server to trigger UDP errors
sleep 1
kill $SERVER_PID 2>/dev/null
wait $CLIENT_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 7: UDS DATAGRAM ERROR SCENARIOS (Lines 485-492, 495-500)"
# Test UDS datagram send/receive errors
rm -f /tmp/dgram_error_stream.sock /tmp/dgram_error_dgram.sock

./persistent_warehouse -s /tmp/dgram_error_stream.sock -d /tmp/dgram_error_dgram.sock -f dgram_error_test.dat -c 3000 -o 3000 -H 3000 >/dev/null 2>&1 &
UDS_PID=$!

for i in {1..10}; do
    if [ -S "/tmp/dgram_error_stream.sock" ] && [ -S "/tmp/dgram_error_dgram.sock" ]; then
        break
    fi
    sleep 0.5
done

if [ -S "/tmp/dgram_error_stream.sock" ] && [ -S "/tmp/dgram_error_dgram.sock" ]; then
    echo "Testing UDS datagram error scenarios (lines 485-500)..."
    
    {
        echo "2"           # Request molecules (UDS datagram)
        echo "1"           # WATER
        echo "25"          # Quantity
        echo "5"           # Back
        echo "3"           # Quit
    } | timeout 8s ./persistent_requester -f /tmp/dgram_error_stream.sock -d /tmp/dgram_error_dgram.sock >/dev/null 2>&1 &
    CLIENT_PID=$!
    
    # Kill server to trigger datagram errors
    sleep 2
    kill $UDS_PID 2>/dev/null
    wait $CLIENT_PID 2>/dev/null
    wait $UDS_PID 2>/dev/null
fi

rm -f /tmp/dgram_error_stream.sock /tmp/dgram_error_dgram.sock

echo ""
echo "📋 Phase 8: SERVER DISCONNECTION MESSAGE (Line 519)"
# Test "Connection to server lost" message
./persistent_warehouse -T 41040 -f disconnect_test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

echo "Testing server disconnection message (line 519)..."

{
    echo "1"               # Add atoms
    echo "1"               # CARBON  
    echo "75"              # Amount
    sleep 2               # Give time for connection establishment
    echo "1"               # Try another command
    echo "2"               # OXYGEN
    echo "100"             # Amount
    sleep 1               # Server gets killed here
} | timeout 8s ./persistent_requester -h localhost -p 41040 >/dev/null 2>&1 &
CLIENT_PID=$!

sleep 3
kill $SERVER_PID 2>/dev/null  # Kill server to trigger disconnection message
wait $CLIENT_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "📋 Phase 9: COMPREHENSIVE ERROR COMBINATIONS"
# Test combinations of errors to hit any remaining paths
echo "Testing error combinations..."

# Multiple invalid connection attempts
for port in 1 2 3 4 5; do
    timeout 1s ./persistent_requester -h localhost -p $port 2>/dev/null &
done
wait

# Invalid hostname combinations
timeout 2s ./persistent_requester -h "invalid1.test" -p 12345 2>/dev/null
timeout 2s ./persistent_requester -h "invalid2.test" -p 12346 2>/dev/null

# UDS errors
timeout 2s ./persistent_requester -f /nonexistent/path.sock 2>/dev/null
timeout 2s ./persistent_requester -f /tmp/no.sock -d /tmp/also_no.sock 2>/dev/null

echo ""
echo "📊 Generating Coverage (accumulative)"
gcov persistent_requester.c 2>/dev/null || true

if [ -f "persistent_requester.c.gcov" ]; then
    CLIENT_COV=$(gcov persistent_requester.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "Client coverage: $CLIENT_COV"
    UNCOVERED=$(grep -c "#####:" persistent_requester.c.gcov || echo "0")
    echo "Uncovered lines: $UNCOVERED"
    
    echo "Specifically targeted uncovered lines still remaining:"
    grep -n "#####:" persistent_requester.c.gcov | grep -E "(81|90|113|114|119|247|248|278|279|280|291|292|310|311|312|313|314|316|317|378|379|380|389|398|399|400|405|406|407|408|471|472|480|485|486|487|489|491|492|495|496|497|498|500|519)" | head -10
else
    echo "No coverage data!"
fi

# Cleanup files but preserve coverage data
rm -f hostname_test.dat uds_dgram_test.dat connection_error_test.dat recv_test.dat udp_error_test.dat dgram_error_test.dat disconnect_test.dat

echo ""
echo "✅ Enhanced client coverage complete!"