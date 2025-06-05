#!/bin/bash

# q5_integrated_test.sh - בדיקה אוטומטית מלאה עם דמיית שרת-לקוח בכל מצבי התקשורת

set -e

echo "🧪 Q5 INTEGRATED AUTOMATIC TEST SUITE"
echo "====================================="
echo "Testing all communication modes: Network, UDS, and Mixed"

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
    pkill -f uds_warehouse 2>/dev/null || true
    rm -f /tmp/test_*.sock /tmp/q5_*.sock 2>/dev/null
    rm -f server_*.log client_*.log test_*.log
}

trap cleanup EXIT

log_test() {
    echo "[$(date '+%H:%M:%S')] $1" >> test_results_q5_integrated.log
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
echo "📦 Building Q5..."
make clean > /dev/null 2>&1
if ! make all > build_integrated.log 2>&1; then
    echo -e "${RED}❌ Build failed!${NC}"
    cat build_integrated.log
    exit 1
fi
echo -e "${GREEN}✅ Build successful${NC}"

# 🌐 TEST 1: Network Mode (TCP + UDP)
echo -e "\n${BLUE}🌐 TEST 1: Network Mode Integration${NC}"
echo "------------------------------------"

cleanup
echo "   🔍 Starting network server..."
./uds_warehouse -T 50001 -U 50002 -c 1000 -o 2000 -H 3000 > server_network.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50001 5; then
    echo "   ✅ Network server started successfully"
    
    # בדיקת TCP + UDP עם לקוח אמיתי
    echo "   🔍 Testing network client integration..."
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
    } | timeout 15s ./uds_requester -h localhost -p 50001 -u 50002 > client_network.log 2>&1
    
    # בדוק תוצאות
    local tcp_ok=false
    local udp_ok=false
    
    if grep -q "SUCCESS.*CARBON" client_network.log; then
        tcp_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_network.log; then
        udp_ok=true
    fi
    
    if $tcp_ok && $udp_ok; then
        test_result "Network mode full integration" "success" "success"
    else
        test_result "Network mode full integration" "success" "fail" "TCP: $tcp_ok, UDP: $udp_ok"
    fi
    
    test_result "Network server startup" "success" "success"
else
    test_result "Network server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔌 TEST 2: UDS Mode (Stream + Datagram)  
echo -e "\n${BLUE}🔌 TEST 2: UDS Mode Integration${NC}"
echo "-----------------------------------"

cleanup
echo "   🔍 Starting UDS server..."
./uds_warehouse -s /tmp/q5_stream.sock -d /tmp/q5_datagram.sock -c 800 -o 1200 -H 1800 > server_uds.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/q5_stream.sock 5; then
    echo "   ✅ UDS server started successfully"
    
    # בדיקת UDS stream + datagram עם לקוח אמיתי
    echo "   🔍 Testing UDS client integration..."
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
    } | timeout 15s ./uds_requester -f /tmp/q5_stream.sock -d /tmp/q5_datagram.sock > client_uds.log 2>&1
    
    # בדוק תוצאות
    local stream_ok=false
    local datagram_ok=false
    
    if grep -q "Connected to UDS stream" client_uds.log; then
        stream_ok=true
    fi
    
    if grep -q -i "delivered\|not enough" client_uds.log; then
        datagram_ok=true
    fi
    
    if $stream_ok && $datagram_ok; then
        test_result "UDS mode full integration" "success" "success"
    else
        test_result "UDS mode full integration" "success" "fail" "Stream: $stream_ok, Datagram: $datagram_ok"
    fi
    
    test_result "UDS server startup" "success" "success"
else
    test_result "UDS server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔀 TEST 3: Mixed Mode 1 (TCP + UDS Datagram)
echo -e "\n${BLUE}🔀 TEST 3: Mixed Mode 1 Integration (TCP + UDS Datagram)${NC}"
echo "--------------------------------------------------------"

cleanup
echo "   🔍 Starting mixed mode 1 server..."
./uds_warehouse -T 50003 -d /tmp/q5_mixed1.sock -c 600 -o 900 -H 1200 > server_mixed1.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50003 3 && wait_for_socket /tmp/q5_mixed1.sock 3; then
    echo "   ✅ Mixed mode 1 server started successfully"
    
    echo "   🔍 Testing mixed mode 1 client..."
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
    } | timeout 15s ./uds_requester -h localhost -p 50003 -d /tmp/q5_mixed1.sock > client_mixed1.log 2>&1
    
    if grep -q "Connected.*TCP.*50003" client_mixed1.log && grep -q -i "delivered\|not enough" client_mixed1.log; then
        test_result "Mixed mode 1 (TCP + UDS datagram)" "success" "success"
    else
        test_result "Mixed mode 1 (TCP + UDS datagram)" "success" "fail"
    fi
else
    test_result "Mixed mode 1 (TCP + UDS datagram)" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔀 TEST 4: Mixed Mode 2 (UDS Stream + UDP)
echo -e "\n${BLUE}🔀 TEST 4: Mixed Mode 2 Integration (UDS Stream + UDP)${NC}"
echo "------------------------------------------------------"

cleanup
echo "   🔍 Starting mixed mode 2 server..."
./uds_warehouse -s /tmp/q5_mixed2.sock -U 50004 -c 400 -o 600 -H 800 > server_mixed2.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/q5_mixed2.sock 3 && wait_for_port 50004 3; then
    echo "   ✅ Mixed mode 2 server started successfully"
    
    echo "   🔍 Testing mixed mode 2 client..."
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
    } | timeout 15s ./uds_requester -f /tmp/q5_mixed2.sock -u 50004 > client_mixed2.log 2>&1
    
    if grep -q "Connected to UDS stream" client_mixed2.log && grep -q -i "delivered\|not enough" client_mixed2.log; then
        test_result "Mixed mode 2 (UDS stream + UDP)" "success" "success"
    else
        test_result "Mixed mode 2 (UDS stream + UDP)" "success" "fail"
    fi
else
    test_result "Mixed mode 2 (UDS stream + UDP)" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 💬 TEST 5: Enhanced Communication
echo -e "\n${BLUE}💬 TEST 5: Enhanced Communication Integration${NC}"
echo "---------------------------------------------"

cleanup
echo "   🔍 Testing enhanced server responses..."
./uds_warehouse -T 50005 -U 50006 > server_enhanced.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50005 3; then
    # בדיקת הודעות SUCCESS/ERROR
    echo "ADD CARBON 1000" | nc localhost 50005 > response_test.log 2>&1
    
    local has_success=false
    local has_status=false
    local has_error=false
    
    if grep -q "SUCCESS:" response_test.log; then
        has_success=true
    fi
    
    if grep -q "Status:" response_test.log; then
        has_status=true
    fi
    
    # בדיקת הודעת שגיאה
    echo "ADD INVALID 100" | nc localhost 50005 > error_test.log 2>&1
    if grep -q "ERROR:" error_test.log; then
        has_error=true
    fi
    
    if $has_success && $has_status && $has_error; then
        test_result "Enhanced communication (SUCCESS/ERROR/Status)" "success" "success"
    else
        test_result "Enhanced communication (SUCCESS/ERROR/Status)" "success" "fail" "SUCCESS: $has_success, Status: $has_status, ERROR: $has_error"
    fi
else
    test_result "Enhanced communication server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🔒 TEST 6: Strict Validation
echo -e "\n${BLUE}🔒 TEST 6: Strict Validation Integration${NC}"
echo "----------------------------------------"

cleanup
echo "   🔍 Testing strict quantity validation..."
./uds_warehouse -T 50007 -U 50008 -c 100 -o 100 -H 100 > server_strict.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50007 3; then
    # בדיקת כמות אפס
    echo "DELIVER WATER 0" | nc -u localhost 50008 > strict_test1.log 2>&1
    
    # בדיקת כמות גדולה מדי  
    echo "DELIVER WATER 999999999999999999999" | nc -u localhost 50008 > strict_test2.log 2>&1
    
    local zero_rejected=false
    local large_rejected=false
    
    if grep -q "ERROR.*Invalid quantity.*0" strict_test1.log; then
        zero_rejected=true
    fi
    
    if grep -q "ERROR.*Invalid quantity" strict_test2.log; then
        large_rejected=true
    fi
    
    if $zero_rejected && $large_rejected; then
        test_result "Strict validation (no defaults)" "success" "success"
    else
        test_result "Strict validation (no defaults)" "success" "fail" "Zero: $zero_rejected, Large: $large_rejected"
    fi
else
    test_result "Strict validation server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# 🚀 TEST 7: Multiple Clients
echo -e "\n${BLUE}🚀 TEST 7: Multiple Clients Integration${NC}"
echo "---------------------------------------"

cleanup
echo "   🔍 Testing multiple concurrent clients..."
./uds_warehouse -T 50009 -U 50010 -c 5000 -o 5000 -H 5000 > server_multi.log 2>&1 &
SERVER_PID=$!

if wait_for_port 50009 3; then
    # הפעל 3 לקוחות במקביל
    local pids=()
    for i in {1..3}; do
        {
            {
                echo "1"; echo "1"; echo "$((100 * i))"; sleep 1; echo "4"
                echo "2"; echo "1"; echo "$i"; sleep 1; echo "5"; echo "3"
            } | timeout 10s ./uds_requester -h localhost -p 50009 -u 50010 > multi_client_$i.log 2>&1
        } &
        pids+=($!)
    done
    
    # חכה לכל הלקוחות
    local all_ok=true
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            all_ok=false
        fi
    done
    
    # בדוק שכולם התחברו
    local connections=0
    for i in {1..3}; do
        if grep -q "Connected" multi_client_$i.log; then
            connections=$((connections + 1))
        fi
    done
    
    if [ $connections -eq 3 ] && $all_ok; then
        test_result "Multiple concurrent clients" "success" "success"
    else
        test_result "Multiple concurrent clients" "success" "fail" "Successful connections: $connections/3"
    fi
else
    test_result "Multiple clients server" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# דו"ח סופי
echo -e "\n${YELLOW}📊 Q5 Integrated Test Results${NC}"
echo "=================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}/${TESTS_TOTAL}"
echo -e "Success Rate: ${GREEN}$(( TESTS_PASSED * 100 / TESTS_TOTAL ))%${NC}"

# שמור דו"ח מפורט
{
    echo "=== Q5 INTEGRATED TEST REPORT ==="
    echo "Generated: $(date)"
    echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    echo "=== Communication Modes Tested ==="
    echo "✓ Network Mode (TCP + UDP)"
    echo "✓ UDS Mode (Stream + Datagram)"  
    echo "✓ Mixed Mode 1 (TCP + UDS Datagram)"
    echo "✓ Mixed Mode 2 (UDS Stream + UDP)"
    echo "✓ Enhanced Communication (SUCCESS/ERROR)"
    echo "✓ Strict Validation (No Defaults)"
    echo "✓ Multiple Concurrent Clients"
    echo ""
    echo "=== Detailed Results ==="
    cat test_results_q5_integrated.log
} > integrated_test_report_q5.txt

echo -e "\n📄 Detailed report saved to: ${BLUE}integrated_test_report_q5.txt${NC}"

cleanup

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "\n${GREEN}🎉 ALL Q5 INTEGRATED TESTS PASSED!${NC}"
    echo -e "${CYAN}🏆 Q5 supports all communication modes perfectly!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some Q5 integrated tests failed. Check the report for details.${NC}"
    exit 1
fi