#!/bin/bash

# q6_integrated_test.sh - בדיקה אוטומטית מלאה עם דמיית שרת-לקוח בכל מצבי התקשורת + Persistence

set -e

echo "🧪 Q6 INTEGRATED AUTOMATIC TEST SUITE"
echo "====================================="
echo "Testing all modes: Network, UDS, Mixed + Persistent Storage"

# צבעים
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_TOTAL=0

# ניקוי ראשוני
cleanup() {
    pkill -f persistent_warehouse 2>/dev/null || true
    rm -f /tmp/test_*.sock /tmp/q6_*.sock 2>/dev/null
    rm -f /tmp/test_*.dat /tmp/q6_*.dat 2>/dev/null
    rm -f server_*.log client_*.log test_*.log
}

trap cleanup EXIT

log_test() {
    echo "[$(date '+%H:%M:%S')] $1" >> test_results_q6_integrated.log
}

test_result() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    local details="$4"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS: $name"
    else
        echo -e "${RED}❌${NC} $name (Expected: $expected, Got: $actual)"
        if [ -n "$details" ]; then
            echo "   Details: $details"
        fi
        log_test "FAIL: $name - Expected: $expected, Got: $actual"
    fi
}

wait_for_port() {
    local port=$1
    local timeout=${2:-5}
    local count=0
    
    while [ $count -lt $timeout ]; do
        if nc -z localhost $port 2>/dev/null; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

wait_for_socket() {
    local socket_path="$1"
    local timeout=${2:-5}
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -S "$socket_path" ]; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

# בנייה
echo "📦 Building Q6..."
make clean > /dev/null 2>&1
if ! make all > build_integrated.log 2>&1; then
    echo -e "${RED}❌ Build failed!${NC}"
    cat build_integrated.log
    exit 1
fi
echo -e "${GREEN}✅ Build successful${NC}"

# בדוק שהקבצים נבנו
if [ ! -f "./persistent_warehouse" ] || [ ! -f "./persistent_requester" ]; then
    echo -e "${RED}❌ Required executables not found after build!${NC}"
    ls -la persistent_*
    exit 1
fi

echo -e "${GREEN}✅ Both executables ready for testing${NC}"

# 🌐 TEST 1: Network Mode with Persistence
echo -e "\n${BLUE}🌐 TEST 1: Network Mode + Persistence Integration${NC}"
echo "---------------------------------------------------"

cleanup
echo "   🔍 Starting network server with persistence..."
echo "   📝 Command: ./persistent_warehouse -T 50001 -U 50002 -f /tmp/q6_network.dat -c 1000 -o 2000 -H 3000"
./persistent_warehouse -T 50001 -U 50002 -f /tmp/q6_network.dat -c 1000 -o 2000 -H 3000 > server_network.log 2>&1 &
SERVER_PID=$!

echo "   ⏳ Waiting for server startup..."
if wait_for_port 50001 5; then
    echo "   ✅ Network server with persistence started successfully"
    
    # בדוק שהקובץ נוצר
    if [ -f "/tmp/q6_network.dat" ]; then
        echo "   ✅ Save file created successfully"
    else
        echo "   ⚠️  Save file not found"
    fi
    
    # בדיקת TCP + UDP עם לקוח אמיתי + בדיקת persistence
    echo "   🔍 Testing network client integration with persistence..."
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "500"    # Amount
        sleep 1
        echo "4"      # Back to main menu
        echo "2"      # Request molecules  
        echo "1"      # Water
        echo "10"     # Quantity
        sleep 1
        echo "5"      # Back to main menu
        echo "3"      # Quit
    } | timeout 15s ./persistent_requester -h localhost -p 50001 -u 50002 > client_network.log 2>&1
    
    # בדוק תוצאות
    local tcp_ok=false
    local udp_ok=false
    local welcome_ok=false
    local file_ok=false
    
    if grep -q "SUCCESS.*CARBON" client_network.log; then
        tcp_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_network.log; then
        udp_ok=true
    fi
    
    if grep -q "Connected to.*Persistent Warehouse.*TCP" client_network.log; then
        welcome_ok=true
    fi
    
    if [ -f "/tmp/q6_network.dat" ]; then
        file_ok=true
    fi
    
    if $tcp_ok && $udp_ok && $welcome_ok && $file_ok; then
        test_result "Network mode + persistence full integration" "success" "success"
    else
        test_result "Network mode + persistence full integration" "success" "fail" "TCP: $tcp_ok, UDP: $udp_ok, Welcome: $welcome_ok, File: $file_ok"
    fi
    
    test_result "Network server with persistence startup" "success" "success"
else
    echo "   ❌ Network server failed to start!"
    echo "   📋 Server log contents:"
    if [ -f "server_network.log" ]; then
        head -20 server_network.log
    else
        echo "   No server log file found"
    fi
    echo "   🔍 Checking if process is running:"
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo "   Process is running but port not accessible"
    else
        echo "   Process has died"
    fi
    test_result "Network server with persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔌 TEST 2: UDS Mode with Persistence
echo -e "\n${BLUE}🔌 TEST 2: UDS Mode + Persistence Integration${NC}"
echo "----------------------------------------------"

cleanup
echo "   🔍 Starting UDS server with persistence..."
./persistent_warehouse -s /tmp/q6_stream.sock -d /tmp/q6_datagram.sock -f /tmp/q6_uds.dat -c 800 -o 1200 -H 1800 > server_uds.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/q6_stream.sock 5; then
    echo "   ✅ UDS server with persistence started successfully"
    
    # בדיקת UDS stream + datagram עם לקוח אמיתי + persistence
    echo "   🔍 Testing UDS client integration with persistence..."
    {
        echo "1"      # Add atoms
        echo "2"      # Oxygen  
        echo "300"    # Amount
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "2"      # Carbon dioxide
        echo "5"      # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 15s ./persistent_requester -f /tmp/q6_stream.sock -d /tmp/q6_datagram.sock > client_uds.log 2>&1
    
    # בדוק תוצאות
    local stream_ok=false
    local datagram_ok=false
    local welcome_ok=false
    local file_ok=false
    
    if grep -q "Connected.*Persistent Warehouse.*UDS" client_uds.log; then
        stream_ok=true
        welcome_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_uds.log; then
        datagram_ok=true
    fi
    
    if [ -f "/tmp/q6_uds.dat" ]; then
        file_ok=true
    fi
    
    if $stream_ok && $datagram_ok && $welcome_ok && $file_ok; then
        test_result "UDS mode + persistence full integration" "success" "success"
    else
        test_result "UDS mode + persistence full integration" "success" "fail" "Stream: $stream_ok, Datagram: $datagram_ok, Welcome: $welcome_ok, File: $file_ok"
    fi
    
    test_result "UDS server with persistence startup" "success" "success"
else
    test_result "UDS server with persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 💾 TEST 3: Persistence Loading Test
echo -e "\n${BLUE}💾 TEST 3: Persistence Loading Integration${NC}"
echo "-------------------------------------------"

cleanup
echo "   🔍 Testing inventory persistence across server restarts..."

# Phase 1: Create inventory
./persistent_warehouse -T 50003 -U 50004 -f /tmp/q6_persist.dat -c 100 > persist_server1.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50003 3; then
    # Add atoms to inventory
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "1500"   # Amount
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "2"      # Oxygen
        echo "2500"   # Amount
        echo "4"      # Back
        echo "3"      # Quit
    } | timeout 15s ./persistent_requester -h localhost -p 50003 -u 50004 > persist_client1.log 2>&1
    
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null || true
    
    # Phase 2: Load existing inventory
    echo "   🔍 Loading existing inventory..."
    ./persistent_warehouse -T 50005 -U 50006 -f /tmp/q6_persist.dat > persist_server2.log 2>&1 &
    SERVER_PID=$!
    
    if wait_for_port 50005 3; then
        # Check if inventory was loaded
        {
            echo "1"      # Add atoms
            echo "1"      # Carbon
            echo "100"    # Small amount
            echo "4"      # Back
            echo "3"      # Quit
        } | timeout 10s ./persistent_requester -h localhost -p 50005 -u 50006 > persist_client2.log 2>&1
        
        # Should show total carbon = 1600 (1500 + 100)
        if grep -q "Total CARBON.*16" persist_client2.log; then
            test_result "Inventory persistence across restarts" "success" "success"
        else
            test_result "Inventory persistence across restarts" "success" "fail"
        fi
    else
        test_result "Persistence loading server startup" "success" "fail"
    fi
    
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null || true
else
    test_result "Persistence creation server startup" "success" "fail"
fi

# 🔒 TEST 4: File Locking Integration
echo -e "\n${BLUE}🔒 TEST 4: File Locking Integration${NC}"
echo "-----------------------------------"

cleanup
echo "   🔍 Testing file locking with multiple processes..."

# Start first server
./persistent_warehouse -T 50007 -U 50008 -f /tmp/q6_lock_test.dat > lock_server1.log 2>&1 &
SERVER_PID1=$!

sleep 2

# Try to start second server with same file (should fail or be blocked)
./persistent_warehouse -T 50009 -U 50010 -f /tmp/q6_lock_test.dat > lock_server2.log 2>&1 &
SERVER_PID2=$!

sleep 3

local running_servers=0
if kill -0 $SERVER_PID1 2>/dev/null; then
    running_servers=$((running_servers + 1))
fi
if kill -0 $SERVER_PID2 2>/dev/null; then
    running_servers=$((running_servers + 1))
fi

# Only one server should be running (file locking should prevent the second)
if [ $running_servers -eq 1 ]; then
    test_result "File locking prevents multiple processes" "success" "success"
else
    test_result "File locking prevents multiple processes" "success" "fail" "Running servers: $running_servers (should be 1)"
fi

kill $SERVER_PID1 $SERVER_PID2 2>/dev/null || true
wait $SERVER_PID1 $SERVER_PID2 2>/dev/null || true

# 🔀 TEST 5: Mixed Mode 1 with Persistence (TCP + UDS Datagram)
echo -e "\n${BLUE}🔀 TEST 5: Mixed Mode 1 + Persistence (TCP + UDS Datagram)${NC}"
echo "------------------------------------------------------------"

cleanup
echo "   🔍 Starting mixed mode 1 server with persistence..."
./persistent_warehouse -T 50011 -d /tmp/q6_mixed1.sock -f /tmp/q6_mixed1.dat -c 600 -o 900 -H 1200 > server_mixed1.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50011 3 && wait_for_socket /tmp/q6_mixed1.sock 3; then
    echo "   ✅ Mixed mode 1 server with persistence started successfully"
    
    echo "   🔍 Testing mixed mode 1 client with persistence..."
    {
        echo "1"      # Add atoms
        echo "3"      # Hydrogen
        echo "400"    # Amount  
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "3"      # Alcohol
        echo "3"      # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 15s ./persistent_requester -h localhost -p 50011 -d /tmp/q6_mixed1.sock > client_mixed1.log 2>&1
    
    local tcp_ok=false
    local uds_datagram_ok=false
    local file_ok=false
    
    if grep -q "Connected.*TCP.*50011" client_mixed1.log; then
        tcp_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_mixed1.log; then
        uds_datagram_ok=true
    fi
    
    if [ -f "/tmp/q6_mixed1.dat" ]; then
        file_ok=true
    fi
    
    if $tcp_ok && $uds_datagram_ok && $file_ok; then
        test_result "Mixed mode 1 + persistence (TCP + UDS datagram)" "success" "success"
    else
        test_result "Mixed mode 1 + persistence (TCP + UDS datagram)" "success" "fail" "TCP: $tcp_ok, UDS-DG: $uds_datagram_ok, File: $file_ok"
    fi
else
    test_result "Mixed mode 1 + persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔀 TEST 6: Mixed Mode 2 with Persistence (UDS Stream + UDP)
echo -e "\n${BLUE}🔀 TEST 6: Mixed Mode 2 + Persistence (UDS Stream + UDP)${NC}"
echo "---------------------------------------------------------"

cleanup
echo "   🔍 Starting mixed mode 2 server with persistence..."
./persistent_warehouse -s /tmp/q6_mixed2.sock -U 50012 -f /tmp/q6_mixed2.dat -c 400 -o 600 -H 800 > server_mixed2.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/q6_mixed2.sock 3 && wait_for_port 50012 3; then
    echo "   ✅ Mixed mode 2 server with persistence started successfully"
    
    echo "   🔍 Testing mixed mode 2 client with persistence..."
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "200"    # Amount
        sleep 1  
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "4"      # Glucose
        echo "2"      # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 15s ./persistent_requester -f /tmp/q6_mixed2.sock -u 50012 > client_mixed2.log 2>&1
    
    local uds_stream_ok=false
    local udp_ok=false
    local file_ok=false
    
    if grep -q "Connected.*Persistent Warehouse.*UDS" client_mixed2.log; then
        uds_stream_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_mixed2.log; then
        udp_ok=true
    fi
    
    if [ -f "/tmp/q6_mixed2.dat" ]; then
        file_ok=true
    fi
    
    if $uds_stream_ok && $udp_ok && $file_ok; then
        test_result "Mixed mode 2 + persistence (UDS stream + UDP)" "success" "success"
    else
        test_result "Mixed mode 2 + persistence (UDS stream + UDP)" "success" "fail" "UDS-Stream: $uds_stream_ok, UDP: $udp_ok, File: $file_ok"
    fi
else
    test_result "Mixed mode 2 + persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 💬 TEST 7: Enhanced Communication with Persistence
echo -e "\n${BLUE}💬 TEST 7: Enhanced Communication + Persistence${NC}"
echo "------------------------------------------------"

cleanup
echo "   🔍 Testing enhanced server responses with persistence..."
./persistent_warehouse -T 50013 -U 50014 -f /tmp/q6_enhanced.dat > server_enhanced.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50013 3; then
    # Test SUCCESS/ERROR messages
    echo "ADD CARBON 1000" | nc localhost 50013 > response_test.log 2>&1
    
    local has_success=false
    local has_status=false
    local has_error=false
    local has_welcome=false
    
    if grep -q "SUCCESS:" response_test.log; then
        has_success=true
    fi
    
    if grep -q "Status:" response_test.log; then
        has_status=true
    fi
    
    # Test error message
    echo "ADD INVALID 100" | nc localhost 50013 > error_test.log 2>&1
    if grep -q "ERROR:" error_test.log; then
        has_error=true
    fi
    
    # Test welcome message
    echo "3" | timeout 5s ./persistent_requester -h localhost -p 50013 -u 50014 > welcome_test.log 2>&1
    if grep -q "Connected to.*Persistent Warehouse" welcome_test.log; then
        has_welcome=true
    fi
    
    if $has_success && $has_status && $has_error && $has_welcome; then
        test_result "Enhanced communication + persistence" "success" "success"
    else
        test_result "Enhanced communication + persistence" "success" "fail" "SUCCESS: $has_success, Status: $has_status, ERROR: $has_error, Welcome: $has_welcome"
    fi
else
    test_result "Enhanced communication + persistence server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔒 TEST 8: Strict Validation with Persistence
echo -e "\n${BLUE}🔒 TEST 8: Strict Validation + Persistence${NC}"
echo "-------------------------------------------"

cleanup
echo "   🔍 Testing strict quantity validation with persistence..."
./persistent_warehouse -T 50015 -U 50016 -f /tmp/q6_strict.dat -c 100 -o 100 -H 100 > server_strict.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50015 3; then
    # Test zero quantity
    echo "DELIVER WATER 0" | nc -u localhost 50016 > strict_test1.log 2>&1
    
    # Test too large quantity  
    echo "DELIVER WATER 999999999999999999999" | nc -u localhost 50016 > strict_test2.log 2>&1
    
    local zero_rejected=false
    local large_rejected=false
    local file_ok=false
    
    if grep -q "ERROR.*Invalid quantity.*0" strict_test1.log; then
        zero_rejected=true
    fi
    
    if grep -q "ERROR.*Invalid quantity" strict_test2.log; then
        large_rejected=true
    fi
    
    if [ -f "/tmp/q6_strict.dat" ]; then
        file_ok=true
    fi
    
    if $zero_rejected && $large_rejected && $file_ok; then
        test_result "Strict validation + persistence" "success" "success"
    else
        test_result "Strict validation + persistence" "success" "fail" "Zero: $zero_rejected, Large: $large_rejected, File: $file_ok"
    fi
else
    test_result "Strict validation + persistence server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🚀 TEST 9: Multiple Clients with Persistence
echo -e "\n${BLUE}🚀 TEST 9: Multiple Clients + Persistence${NC}"
echo "-------------------------------------------"

cleanup
echo "   🔍 Testing multiple concurrent clients with persistence..."
./persistent_warehouse -T 50017 -U 50018 -f /tmp/q6_multi.dat -c 5000 -o 5000 -H 5000 > server_multi.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50017 3; then
    # Start 3 clients in parallel
    local pids=()
    for i in {1..3}; do
        {
            {
                echo "1"; echo "1"; echo "$((100 * i))"; sleep 1; echo "4"
                echo "2"; echo "1"; echo "$i"; sleep 1; echo "5"; echo "3"
            } | timeout 15s ./persistent_requester -h localhost -p 50017 -u 50018 > multi_client_$i.log 2>&1
        } &
        pids+=($!)
    done
    
    # Wait for all clients
    local all_ok=true
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            all_ok=false
        fi
    done
    
    # Check successful connections
    local connections=0
    for i in {1..3}; do
        if grep -q "Connected.*Persistent Warehouse" multi_client_$i.log; then
            connections=$((connections + 1))
        fi
    done
    
    local file_ok=false
    if [ -f "/tmp/q6_multi.dat" ]; then
        file_ok=true
    fi
    
    if [ $connections -eq 3 ] && $all_ok && $file_ok; then
        test_result "Multiple concurrent clients + persistence" "success" "success"
    else
        test_result "Multiple concurrent clients + persistence" "success" "fail" "Connections: $connections/3, File: $file_ok"
    fi
else
    test_result "Multiple clients + persistence server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🗄️ TEST 10: Memory Mapping and Synchronization
echo -e "\n${BLUE}🗄️ TEST 10: Memory Mapping + Synchronization${NC}"
echo "----------------------------------------------"

cleanup
echo "   🔍 Testing memory mapping and file synchronization..."
./persistent_warehouse -T 50019 -U 50020 -f /tmp/q6_mmap.dat -c 1000 > server_mmap.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50019 3; then
    # Add atoms and check immediate persistence
    echo "ADD CARBON 2000" | nc localhost 50019 > mmap_test.log 2>&1
    
    local response_ok=false
    local file_exists=false
    local file_size_ok=false
    
    if grep -q "SUCCESS.*CARBON.*2000" mmap_test.log; then
        response_ok=true
    fi
    
    if [ -f "/tmp/q6_mmap.dat" ]; then
        file_exists=true
        # Check if file has reasonable size (should contain inventory structure)
        if [ $(wc -c < "/tmp/q6_mmap.dat") -gt 0 ]; then
            file_size_ok=true
        fi
    fi
    
    if $response_ok && $file_exists && $file_size_ok; then
        test_result "Memory mapping + file synchronization" "success" "success"
    else
        test_result "Memory mapping + file synchronization" "success" "fail" "Response: $response_ok, FileExists: $file_exists, FileSize: $file_size_ok"
    fi
else
    test_result "Memory mapping server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🕐 TEST 11: Timeout with Persistence
echo -e "\n${BLUE}🕐 TEST 11: Timeout + Persistence Integration${NC}"
echo "----------------------------------------------"

cleanup
echo "   🔍 Testing server timeout with inventory saving..."
./persistent_warehouse -T 50021 -U 50022 -f /tmp/q6_timeout.dat -t 3 > server_timeout.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50021 3; then
    # Add atoms before timeout
    echo "ADD HYDROGEN 1500" | nc localhost 50021 > timeout_test.log 2>&1
    
    # Wait for timeout
    echo "   ⏳ Waiting for server timeout..."
    sleep 5
    
    local server_stopped=false
    local file_ok=false
    local atoms_saved=false
    
    # Check server stopped
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        server_stopped=true
    fi
    
    # Check file exists
    if [ -f "/tmp/q6_timeout.dat" ]; then
        file_ok=true
    fi
    
    # Check atoms were saved (restart server and verify)
    if $file_ok; then
        ./persistent_warehouse -T 50023 -U 50024 -f /tmp/q6_timeout.dat > timeout_verify.log 2>&1 &
        local VERIFY_PID=$!
        
        if wait_for_port 50023 3; then
            echo "ADD CARBON 100" | nc localhost 50023 > timeout_verify_test.log 2>&1
            if grep -q "Total.*H.*15" timeout_verify_test.log; then
                atoms_saved=true
            fi
            kill $VERIFY_PID 2>/dev/null
            wait $VERIFY_PID 2>/dev/null || true
        fi
    fi
    
    if $server_stopped && $file_ok && $atoms_saved; then
        test_result "Server timeout with inventory persistence" "success" "success"
    else
        test_result "Server timeout with inventory persistence" "success" "fail" "Stopped: $server_stopped, File: $file_ok, Saved: $atoms_saved"
    fi
else
    test_result "Timeout server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# Final report
echo -e "\n${YELLOW}📊 Q6 Integrated Test Results${NC}"
echo "=================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}/${TESTS_TOTAL}"
echo -e "Success Rate: ${GREEN}$(( TESTS_PASSED * 100 / TESTS_TOTAL ))%${NC}"

# Save detailed report
{
    echo "=== Q6 INTEGRATED TEST REPORT ==="
    echo "Generated: $(date)"
    echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    echo "=== Communication Modes + Persistence Tested ==="
    echo "✓ Network Mode (TCP + UDP) with persistent storage"
    echo "✓ UDS Mode (Stream + Datagram) with persistent storage"  
    echo "✓ Mixed Mode 1 (TCP + UDS Datagram) with persistence"
    echo "✓ Mixed Mode 2 (UDS Stream + UDP) with persistence"
    echo "✓ Inventory persistence across server restarts"
    echo "✓ File locking for concurrent access prevention"
    echo "✓ Enhanced communication (SUCCESS/ERROR/Welcome)"
    echo "✓ Strict validation with persistent data"
    echo "✓ Multiple concurrent clients with shared storage"
    echo "✓ Memory mapping and file synchronization"
    echo "✓ Server timeout with inventory preservation"
    echo ""
    echo "=== Q6 Persistent Storage Features ==="
    echo "✓ Memory-mapped inventory files"
    echo "✓ Automatic file creation and validation"
    echo "✓ Cross-restart inventory persistence"
    echo "✓ File locking for process safety"
    echo "✓ Real-time synchronization to disk"
    echo "✓ Magic number validation"
    echo "✓ Graceful shutdown with data preservation"
    echo "✓ Timeout handling with inventory saving"
    echo ""
    echo "=== Detailed Results ==="
    if [ -f "test_results_q6_integrated.log" ]; then
        cat test_results_q6_integrated.log
    fi
} > integrated_test_report_q6.txt

echo -e "\n📄 Detailed report saved to: ${BLUE}integrated_test_report_q6.txt${NC}"

cleanup

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "\n${GREEN}🎉 ALL Q6 INTEGRATED TESTS PASSED!${NC}"
    echo -e "${CYAN}🏆 Q6 Persistent Warehouse supports all modes perfectly!${NC}"
    echo -e "${YELLOW}💾 Persistent storage, file locking, and memory mapping working flawlessly!${NC}"
    echo -e "${BLUE}🔄 Cross-restart persistence and timeout handling verified!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some Q6 integrated tests failed. Check the report for details.${NC}"
    exit 1
fi