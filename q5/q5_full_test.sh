#!/bin/bash

# q5_full_test.sh - בדיקה אוטומטית מלאה עם UDS ו-Network

echo "🧪 Q5 FULL AUTOMATIC TEST SUITE (UDS + Network)"
echo "================================================"

# צבעים
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_TOTAL=0

# ניקוי קבצי לוג ו-sockets
cleanup() {
    rm -f server_*.log client_*.log test_results_q5.log
    rm -f /tmp/test_*.sock /tmp/stream*.sock /tmp/datagram*.sock 2>/dev/null
    # הרג תהליכי שרת שנותרו
    pkill -f uds_warehouse 2>/dev/null || true
    sleep 1
}

trap cleanup EXIT

# בנייה
echo "📦 Building Q5..."
make clean > /dev/null 2>&1
if ! make all > build_q5.log 2>&1; then
    echo -e "${RED}❌ Build failed!${NC}"
    cat build_q5.log
    exit 1
fi
echo -e "${GREEN}✅ Build successful${NC}"

test_result() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌${NC} $name (Expected: $expected, Got: $actual)"
    fi
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

# בדיקות כשלון צפויות
echo -e "\n${BLUE}🖥️  Server Failure Tests${NC}"
echo "------------------------"

test_server_failure() {
    local name="$1"
    local cmd="$2"
    
    if timeout 2s $cmd > /dev/null 2>&1; then
        test_result "$name" "fail" "success"
    else
        test_result "$name" "fail" "fail"
    fi
}

test_server_failure "No arguments" "./uds_warehouse"
test_server_failure "Invalid TCP port" "./uds_warehouse -T 0"
test_server_failure "Invalid UDS path (empty)" "./uds_warehouse -s ''"
test_server_failure "Same TCP/UDP ports" "./uds_warehouse -T 12345 -U 12345"
test_server_failure "No connection type" "./uds_warehouse -c 100"

echo -e "\n${BLUE}💻 Client Failure Tests${NC}"
echo "-----------------------"

test_client_failure() {
    local name="$1"
    local cmd="$2"
    
    if timeout 3s $cmd > /dev/null 2>&1; then
        test_result "$name" "fail" "success"
    else
        test_result "$name" "fail" "fail"
    fi
}

test_client_failure "No arguments" "./uds_requester"
test_client_failure "Missing network host" "./uds_requester -p 12345"
test_client_failure "Missing UDS stream" "./uds_requester -d /tmp/test.sock"
test_client_failure "Mixed UDS and network" "./uds_requester -h localhost -p 12345 -f /tmp/test.sock"
test_client_failure "Non-existent UDS socket" "./uds_requester -f /tmp/nonexistent.sock"

# בדיקות Network (TCP/UDP)
echo -e "\n${BLUE}🌐 Network Mode Tests${NC}"
echo "---------------------"

# שרת network בסיסי
echo "   🔍 Testing basic network server..."
cleanup
./uds_warehouse -T 40001 -U 40002 > server_network.log 2>&1 &
SERVER_PID=$!

if wait_for_port 40001 3; then
    # בדיקת TCP
    echo "ADD CARBON 100" | nc localhost 40001 > client_network_tcp.log 2>&1
    if grep -q "SUCCESS" client_network_tcp.log; then
        test_result "Network TCP communication" "success" "success"
    else
        test_result "Network TCP communication" "success" "fail"
    fi
    
    # בדיקת UDP
    echo "DELIVER WATER 1" | nc -u localhost 40002 > client_network_udp.log 2>&1
    if grep -q -i "delivered\|not enough" client_network_udp.log; then
        test_result "Network UDP communication" "success" "success"
    else
        test_result "Network UDP communication" "success" "fail"
    fi
    
    test_result "Network server startup" "success" "success"
else
    test_result "Network server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקות UDS
echo -e "\n${BLUE}🔌 UDS Mode Tests${NC}"
echo "------------------"

# שרת UDS בסיסי
echo "   🔍 Testing basic UDS server..."
cleanup
./uds_warehouse -s /tmp/test_stream.sock -d /tmp/test_datagram.sock > server_uds.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/test_stream.sock 3; then
    # בדיקת UDS stream
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "200"    # Amount
        echo "4"      # Back
        echo "3"      # Quit
    } | timeout 10s ./uds_requester -f /tmp/test_stream.sock -d /tmp/test_datagram.sock > client_uds.log 2>&1
    
    if grep -q "Connected to UDS" client_uds.log; then
        test_result "UDS connection" "success" "success"
    else
        test_result "UDS connection" "success" "fail"
    fi
    
    test_result "UDS server startup" "success" "success"
else
    test_result "UDS server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקות Mixed Mode
echo -e "\n${BLUE}🔀 Mixed Mode Tests${NC}"
echo "-------------------"

# TCP + UDS datagram
echo "   🔍 Testing TCP + UDS datagram..."
cleanup
./uds_warehouse -T 40003 -d /tmp/test_mixed.sock -c 500 -o 500 -H 500 > server_mixed.log 2>&1 &
SERVER_PID=$!

if wait_for_port 40003 3 && wait_for_socket /tmp/test_mixed.sock 3; then
    # בדיקת TCP
    echo "ADD OXYGEN 100" | nc localhost 40003 > /dev/null 2>&1
    
    # בדיקת UDS datagram (מורכב יותר - צריך לקוח אמיתי)
    echo -e "1\n2\n50\n4\n3" | timeout 5s ./uds_requester -h localhost -p 40003 -d /tmp/test_mixed.sock > client_mixed.log 2>&1
    
    if grep -q "Connected" client_mixed.log; then
        test_result "Mixed mode (TCP + UDS datagram)" "success" "success"
    else
        test_result "Mixed mode (TCP + UDS datagram)" "success" "fail"
    fi
else
    test_result "Mixed mode (TCP + UDS datagram)" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקת אימות קפדני
echo -e "\n${BLUE}🔒 Strict Validation Tests${NC}"
echo "----------------------------"

echo "   🔍 Testing strict quantity validation..."
cleanup
./uds_warehouse -T 40004 -U 40005 -c 100 -o 100 -H 100 > server_validation.log 2>&1 &
SERVER_PID=$!

if wait_for_port 40004 3; then
    # בדיקת כמות לא תקינה
    echo "DELIVER WATER 0" | nc -u localhost 40005 > client_validation.log 2>&1
    if grep -q "ERROR.*Invalid quantity" client_validation.log; then
        test_result "Strict quantity validation (zero)" "success" "success"
    else
        test_result "Strict quantity validation (zero)" "success" "fail"
    fi
    
    # בדיקת כמות גדולה מדי
    echo "DELIVER WATER 999999999999999999999" | nc -u localhost 40005 > client_validation2.log 2>&1
    if grep -q "ERROR.*Invalid quantity" client_validation2.log; then
        test_result "Strict quantity validation (too large)" "success" "success"
    else
        test_result "Strict quantity validation (too large)" "success" "fail"
    fi
else
    test_result "Validation server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקת תקשורת משופרת
echo -e "\n${BLUE}💬 Enhanced Communication Tests${NC}"
echo "--------------------------------"

echo "   🔍 Testing enhanced client feedback..."
cleanup
./uds_warehouse -T 40006 -U 40007 > server_communication.log 2>&1 &
SERVER_PID=$!

if wait_for_port 40006 3; then
    # בדיקת הודעות SUCCESS/ERROR
    echo "ADD CARBON 500" | nc localhost 40006 > client_communication.log 2>&1
    
    local has_success=false
    local has_status=false
    
    if grep -q "SUCCESS:" client_communication.log; then
        has_success=true
    fi
    
    if grep -q "Status:" client_communication.log; then
        has_status=true
    fi
    
    if $has_success && $has_status; then
        test_result "Enhanced client feedback" "success" "success"
    else
        test_result "Enhanced client feedback" "success" "fail"
    fi
else
    test_result "Communication server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# דו"ח סופי
echo -e "\n${YELLOW}📊 Final Test Results${NC}"
echo "====================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}/${TESTS_TOTAL}"
echo -e "Success Rate: ${GREEN}$(( TESTS_PASSED * 100 / TESTS_TOTAL ))%${NC}"

# שמור דו"ח
{
    echo "=== Q5 UDS + Network TEST REPORT ==="
    echo "Generated: $(date)"
    echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    echo "Q5 Features Tested:"
    echo "- Network mode (TCP/UDP)"
    echo "- UDS mode (stream/datagram)"
    echo "- Mixed mode combinations"
    echo "- Strict quantity validation"
    echo "- Enhanced client feedback"
    echo "- Error handling"
} > test_report_q5.txt

echo -e "\n📄 Detailed report saved to: ${BLUE}test_report_q5.txt${NC}"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "\n${GREEN}🎉 ALL Q5 TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some Q5 tests failed. Check the report for details.${NC}"
    exit 1
fi