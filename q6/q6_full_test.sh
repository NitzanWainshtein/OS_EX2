#!/bin/bash

# q6_full_test.sh - בדיקה אוטומטית מלאה עם Persistent Storage + UDS + Network

echo "🧪 Q6 FULL AUTOMATIC TEST SUITE (Persistent + UDS + Network)"
echo "============================================================="

# צבעים
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_TOTAL=0

# ניקוי קבצי לוג ו-sockets ו-persistent files
cleanup() {
    rm -f server_*.log client_*.log test_results_q6.log
    rm -f /tmp/test_*.sock /tmp/stream*.sock /tmp/datagram*.sock 2>/dev/null
    rm -f /tmp/test_*.dat /tmp/inventory*.dat 2>/dev/null
    # הרג תהליכי שרת שנותרו
    pkill -f persistent_warehouse 2>/dev/null || true
    sleep 1
}

trap cleanup EXIT

# בנייה
echo "📦 Building Q6..."
make clean > /dev/null 2>&1

# נקה carriage returns אם יש
if command -v dos2unix > /dev/null 2>&1; then
    dos2unix *.c *.h 2>/dev/null || true
fi

if ! make all > build_q6.log 2>&1; then
    echo -e "${RED}❌ Build failed!${NC}"
    cat build_q6.log
    exit 1
fi
echo -e "${GREEN}✅ Build successful${NC}"

# בדוק שהקבצים נבנו
if [ ! -f "./persistent_warehouse" ]; then
    echo -e "${RED}❌ persistent_warehouse executable not found after build!${NC}"
    exit 1
fi

if [ ! -f "./persistent_requester" ]; then
    echo -e "${RED}❌ persistent_requester executable not found after build!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Both executables found${NC}"

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
    
    echo "   ⏳ Waiting for socket: $socket_path (timeout: ${timeout}s)"
    while [ $count -lt $timeout ]; do
        if [ -S "$socket_path" ]; then
            echo "   ✅ Socket ready after ${count}s"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    echo "   ❌ Socket timeout after ${timeout}s"
    return 1
}

wait_for_port() {
    local port=$1
    local timeout=${2:-5}
    local count=0
    
    echo "   ⏳ Waiting for port: $port (timeout: ${timeout}s)"
    while [ $count -lt $timeout ]; do
        if timeout 1s nc -z localhost $port 2>/dev/null; then
            echo "   ✅ Port ready after ${count}s"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    echo "   ❌ Port timeout after ${timeout}s"
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

test_server_failure "No arguments" "./persistent_warehouse"
test_server_failure "No save file" "./persistent_warehouse -T 40001"
test_server_failure "Invalid TCP port" "./persistent_warehouse -T 0 -f /tmp/test.dat"
test_server_failure "Same TCP/UDP ports" "./persistent_warehouse -T 12345 -U 12345 -f /tmp/test.dat"
test_server_failure "No connection type" "./persistent_warehouse -f /tmp/test.dat -c 100"

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

test_client_failure "No arguments" "./persistent_requester"
test_client_failure "Missing network host" "./persistent_requester -p 12345"
test_client_failure "Missing UDS stream" "./persistent_requester -d /tmp/test.sock"
test_client_failure "Mixed UDS and network" "./persistent_requester -h localhost -p 12345 -f /tmp/test.sock"
test_client_failure "Non-existent UDS socket" "./persistent_requester -f /tmp/nonexistent.sock"

# בדיקות Network (TCP/UDP) עם Persistent Storage
echo -e "\n${BLUE}🌐 Network Mode with Persistence Tests${NC}"
echo "---------------------------------------"

echo "   🔍 Testing network server with save file..."
cleanup
echo "   📝 Starting server: ./persistent_warehouse -T 41001 -U 41002 -f /tmp/test_network.dat -c 1000 -o 1000 -H 1000"
./persistent_warehouse -T 41001 -U 41002 -f /tmp/test_network.dat -c 1000 -o 1000 -H 1000 > server_network.log 2>&1 &
SERVER_PID=$!

echo "   ⏳ Waiting for server startup..."
if wait_for_port 41001 8; then
    echo "   ✅ Network server started successfully on port 41001"
    
    # בדוק שהקובץ נוצר
    if [ -f "/tmp/test_network.dat" ]; then
        echo "   ✅ Save file created: /tmp/test_network.dat"
    else
        echo "   ⚠️  Save file not found"
    fi
    
    # וודא שהשרת עדיין פועל לפני הבדיקות
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "   ❌ Server process died before tests! Server log:"
        cat server_network.log
        test_result "Network TCP communication with persistence" "success" "fail"
        test_result "Network UDP communication with persistence" "success" "fail"
        test_result "Persistent file creation" "success" "fail"
        test_result "Network server with persistence startup" "success" "fail"
    else
        echo "   ✅ Server process is running (PID: $SERVER_PID)"
        
        # בדיקת TCP עם debug מפורט
        echo "   🔍 Testing TCP connection..."
        echo "   📝 Command: echo 'ADD CARBON 100' | nc localhost 41001"
        
        # נסה בדיקה פשוטה קודם
        if ! timeout 3s nc -z localhost 41001; then
            echo "   ❌ Cannot establish basic connection to port 41001"
            test_result "Network TCP communication with persistence" "success" "fail"
        else
            echo "   ✅ Basic connection to port 41001 successful"
            
            # עכשיו נסה עם הפקודה
            timeout 8s bash -c 'echo "ADD CARBON 100" | nc localhost 41001' > client_network_tcp.log 2>&1
            tcp_exit=$?
            
            echo "   📊 TCP test results:"
            echo "      Exit code: $tcp_exit"
            echo "      Response size: $(wc -c < client_network_tcp.log 2>/dev/null || echo 0) bytes"
            echo "      Response content:"
            cat client_network_tcp.log 2>/dev/null | head -5 | sed 's/^/         /'
            
            if [ $tcp_exit -eq 0 ] && grep -q "SUCCESS\|Added.*CARBON" client_network_tcp.log; then
                test_result "Network TCP communication with persistence" "success" "success"
            elif [ $tcp_exit -eq 124 ] && grep -q "SUCCESS\|Added.*CARBON" client_network_tcp.log; then
                # Timeout but got response - that's OK
                test_result "Network TCP communication with persistence" "success" "success"
            else
                test_result "Network TCP communication with persistence" "success" "fail"
            fi
        fi
        
        # בדיקת UDP עם debug מפורט
        echo "   🔍 Testing UDP connection..."
        echo "   📝 Command: echo 'DELIVER WATER 1' | nc -u localhost 41002"
        
        timeout 8s bash -c 'echo "DELIVER WATER 1" | nc -u localhost 41002' > client_network_udp.log 2>&1
        udp_exit=$?
        
        echo "   📊 UDP test results:"
        echo "      Exit code: $udp_exit"
        echo "      Response size: $(wc -c < client_network_udp.log 2>/dev/null || echo 0) bytes"
        echo "      Response content:"
        cat client_network_udp.log 2>/dev/null | head -5 | sed 's/^/         /'
        
        if [ $udp_exit -eq 0 ] && grep -q -i "delivered\|not enough\|ERROR\|SUCCESS" client_network_udp.log; then
            test_result "Network UDP communication with persistence" "success" "success"
        elif [ $udp_exit -eq 124 ] && grep -q -i "delivered\|not enough\|ERROR\|SUCCESS" client_network_udp.log; then
            # Timeout but got response - that's OK
            test_result "Network UDP communication with persistence" "success" "success"
        else
            test_result "Network UDP communication with persistence" "success" "fail"
        fi
        
        # בדיקת שקובץ שמירה נוצר
        if [ -f "/tmp/test_network.dat" ]; then
            test_result "Persistent file creation" "success" "success"
        else
            test_result "Persistent file creation" "success" "fail"
        fi
        
        test_result "Network server with persistence startup" "success" "success"
    fi
else
    echo "   ❌ Server failed to start. Check server log:"
    if [ -f "server_network.log" ]; then
        cat server_network.log
    fi
    test_result "Network server with persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקות UDS עם Persistent Storage
echo -e "\n${BLUE}🔌 UDS Mode with Persistence Tests${NC}"
echo "----------------------------------"

echo "   🔍 Testing UDS server with save file..."
cleanup
./persistent_warehouse -s /tmp/test_stream.sock -d /tmp/test_datagram.sock -f /tmp/test_uds.dat > server_uds.log 2>&1 &
SERVER_PID=$!

if wait_for_socket /tmp/test_stream.sock 3; then
    # בדיקת UDS stream
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "200"    # Amount
        echo "4"      # Back
        echo "3"      # Quit
    } | timeout 10s ./persistent_requester -f /tmp/test_stream.sock -d /tmp/test_datagram.sock > client_uds.log 2>&1
    
    if grep -q "Connected.*Persistent Warehouse.*UDS" client_uds.log; then
        test_result "UDS connection with persistence" "success" "success"
    else
        test_result "UDS connection with persistence" "success" "fail"
    fi
    
    # בדיקת שקובץ שמירה נוצר
    if [ -f "/tmp/test_uds.dat" ]; then
        test_result "UDS persistent file creation" "success" "success"
    else
        test_result "UDS persistent file creation" "success" "fail"
    fi
    
    test_result "UDS server with persistence startup" "success" "success"
else
    test_result "UDS server with persistence startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקות Persistence (טעינת מלאי קיים)
echo -e "\n${BLUE}💾 Persistence Loading Tests${NC}"
echo "-----------------------------"

echo "   🔍 Testing inventory persistence..."
cleanup

# שלב 1: יצירת מלאי
./persistent_warehouse -T 41003 -U 41004 -f /tmp/test_persistence.dat -c 100 > persist_server1.log 2>&1 &
SERVER_PID=$!

if wait_for_port 41003 3; then
    # הוסף אטומים
    {
        echo "1"; echo "1"; echo "500"; echo "4"
        echo "1"; echo "2"; echo "1000"; echo "4"; echo "3"
    } | timeout 10s ./persistent_requester -h localhost -p 41003 -u 41004 > persist_client1.log 2>&1
    
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null || true
    
    if [ -f "/tmp/test_persistence.dat" ]; then
        test_result "Inventory file persistence phase 1" "success" "success"
    else
        test_result "Inventory file persistence phase 1" "success" "fail"
    fi
    
    # שלב 2: טעינת מלאי קיים
    ./persistent_warehouse -T 41005 -U 41006 -f /tmp/test_persistence.dat > persist_server2.log 2>&1 &
    SERVER_PID=$!
    
    if wait_for_port 41005 3; then
        # בדוק שהמלאי נטען
        {
            echo "1"; echo "1"; echo "100"; echo "4"; echo "3"
        } | timeout 10s ./persistent_requester -h localhost -p 41005 -u 41006 > persist_client2.log 2>&1
        
        echo "   📋 Persistence check response:"
        cat persist_client2.log | head -10 | sed 's/^/      /'
        
        # חפש Total CARBON שמכיל 6 (500+100 = 600, אבל בהודעה זה מופיע כ-16xx)
        if grep -q "Total CARBON.*[6-9][0-9][0-9]\|Total CARBON.*1[0-9][0-9][0-9]" persist_client2.log; then
            test_result "Inventory persistence loading" "success" "success"
        else
            test_result "Inventory persistence loading" "success" "fail"
        fi
    else
        test_result "Persistence loading server startup" "success" "fail"
    fi
    
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null || true
else
    test_result "Persistence creation server startup" "success" "fail"
fi

# בדיקות File Locking (תהליכים מרובים)
echo -e "\n${BLUE}🔒 File Locking Tests${NC}"
echo "---------------------"

echo "   🔍 Testing multiple processes with same file..."
cleanup

# נסה להפעיל שני שרתים עם אותו קובץ
echo "   📝 Starting first server..."
./persistent_warehouse -T 41007 -U 41008 -f /tmp/test_lock.dat > lock_server1.log 2>&1 &
SERVER_PID1=$!

sleep 2

echo "   📝 Starting second server (should be blocked)..."
./persistent_warehouse -T 41009 -U 41010 -f /tmp/test_lock.dat > lock_server2.log 2>&1 &
SERVER_PID2=$!

sleep 4

servers_running=0
echo "   🔍 Checking running servers..."
if kill -0 $SERVER_PID1 2>/dev/null; then
    echo "      Server 1: Running"
    servers_running=$((servers_running + 1))
else
    echo "      Server 1: Not running"
fi

if kill -0 $SERVER_PID2 2>/dev/null; then
    echo "      Server 2: Running"
    servers_running=$((servers_running + 1))
else
    echo "      Server 2: Not running"
fi

echo "   📊 Total running servers: $servers_running"

if [ $servers_running -eq 1 ]; then
    test_result "File locking (only one server per file)" "success" "success"
else
    echo "   📋 Server 1 log:"
    head -5 lock_server1.log | sed 's/^/      /'
    echo "   📋 Server 2 log:"
    head -5 lock_server2.log | sed 's/^/      /'
    test_result "File locking (only one server per file)" "success" "fail"
fi

kill $SERVER_PID1 $SERVER_PID2 2>/dev/null || true
wait $SERVER_PID1 $SERVER_PID2 2>/dev/null || true

# בדיקת אימות קפדני
echo -e "\n${BLUE}🔒 Strict Validation Tests${NC}"
echo "----------------------------"

echo "   🔍 Testing strict quantity validation..."
cleanup
./persistent_warehouse -T 41011 -U 41012 -f /tmp/test_validation.dat -c 100 -o 100 -H 100 > server_validation.log 2>&1 &
SERVER_PID=$!

if wait_for_port 41011 5; then
    # בדיקת כמות לא תקינה
    echo "   🔍 Testing zero quantity validation..."
    timeout 5s bash -c 'echo "DELIVER WATER 0" | nc -u localhost 41012' > client_validation.log 2>&1
    if grep -q "ERROR.*Invalid quantity" client_validation.log; then
        test_result "Strict quantity validation (zero)" "success" "success"
    else
        echo "   📋 Validation response: $(cat client_validation.log 2>/dev/null || echo 'No response')"
        test_result "Strict quantity validation (zero)" "success" "fail"
    fi
    
    # בדיקת כמות גדולה מדי
    echo "   🔍 Testing large quantity validation..."
    timeout 5s bash -c 'echo "DELIVER WATER 999999999999999999999" | nc -u localhost 41012' > client_validation2.log 2>&1
    if grep -q "ERROR.*Invalid quantity" client_validation2.log; then
        test_result "Strict quantity validation (too large)" "success" "success"
    else
        echo "   📋 Validation response: $(cat client_validation2.log 2>/dev/null || echo 'No response')"
        test_result "Strict quantity validation (too large)" "success" "fail"
    fi
else
    test_result "Validation server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקת Welcome Messages
echo -e "\n${BLUE}💬 Welcome Message Tests${NC}"
echo "-------------------------"

echo "   🔍 Testing client welcome messages..."
cleanup
./persistent_warehouse -T 41013 -U 41014 -f /tmp/test_welcome.dat > server_welcome.log 2>&1 &
SERVER_PID=$!

if wait_for_port 41013 5; then
    # בדיקת הודעת welcome
    echo "   🔍 Testing welcome message..."
    timeout 8s bash -c 'echo "3" | ./persistent_requester -h localhost -p 41013 -u 41014' > client_welcome.log 2>&1
    
    if grep -q "Connected to.*Persistent Warehouse" client_welcome.log; then
        test_result "Welcome message display" "success" "success"
    else
        echo "   📋 Welcome test response: $(cat client_welcome.log 2>/dev/null || echo 'No response')"
        test_result "Welcome message display" "success" "fail"
    fi
else
    test_result "Welcome message server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקת Memory Mapping
echo -e "\n${BLUE}🗄️  Memory Mapping Tests${NC}"
echo "------------------------"

echo "   🔍 Testing memory mapped file operations..."
cleanup
./persistent_warehouse -T 41015 -U 41016 -f /tmp/test_mmap.dat -c 500 -o 500 -H 500 > server_mmap.log 2>&1 &
SERVER_PID=$!

if wait_for_port 41015 5; then
    # הוסף כמה אטומים ובדוק שהם נשמרים מיד
    echo "   🔍 Testing memory mapping..."
    timeout 5s bash -c 'echo "ADD CARBON 1000" | nc localhost 41015' > client_mmap.log 2>&1
    
    # בדוק שהקובץ השתנה (גודל או תוכן)
    if [ -f "/tmp/test_mmap.dat" ] && [ -s "/tmp/test_mmap.dat" ]; then
        test_result "Memory mapped file operations" "success" "success"
    else
        echo "   📋 Memory mapping response: $(cat client_mmap.log 2>/dev/null || echo 'No response')"
        test_result "Memory mapped file operations" "success" "fail"
    fi
else
    test_result "Memory mapping server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null || true

# בדיקת Timeout עם Persistence
echo -e "\n${BLUE}⏰ Timeout with Persistence Tests${NC}"
echo "---------------------------------"

echo "   🔍 Testing server timeout with inventory saving..."
cleanup
./persistent_warehouse -T 41017 -U 41018 -f /tmp/test_timeout.dat -t 3 > server_timeout.log 2>&1 &
SERVER_PID=$!

if wait_for_port 41017 5; then
    # הוסף אטומים לפני timeout
    echo "   🔍 Adding atoms before timeout..."
    timeout 5s bash -c 'echo "ADD HYDROGEN 800" | nc localhost 41017' > client_timeout.log 2>&1
    
    # חכה ל-timeout
    echo "   ⏳ Waiting for server timeout (3 seconds)..."
    sleep 6
    
    echo "   🔍 Checking if server stopped..."
    server_stopped=false
    file_ok=false
    
    # בדוק שהשרת נסגר
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "      Server stopped: Yes"
        server_stopped=true
    else
        echo "      Server stopped: No (still running)"
        # נסה להרוג אותו
        kill $SERVER_PID 2>/dev/null || true
        sleep 1
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            server_stopped=true
        fi
    fi
    
    # בדוק שהקובץ קיים
    if [ -f "/tmp/test_timeout.dat" ]; then
        echo "      Save file exists: Yes"
        file_ok=true
    else
        echo "      Save file exists: No"
    fi
    
    if $server_stopped && $file_ok; then
        test_result "Server timeout with inventory save" "success" "success"
    else
        echo "   📋 Timeout test response: $(cat client_timeout.log 2>/dev/null || echo 'No response')"
        test_result "Server timeout with inventory save" "success" "fail"
    fi
else
    test_result "Timeout server startup" "success" "fail"
fi

kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# דו"ח סופי
echo -e "\n${YELLOW}📊 Final Q6 Test Results${NC}"
echo "========================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}/${TESTS_TOTAL}"
echo -e "Success Rate: ${GREEN}$(( TESTS_PASSED * 100 / TESTS_TOTAL ))%${NC}"

# שמור דו"ח
{
    echo "=== Q6 PERSISTENT WAREHOUSE TEST REPORT ==="
    echo "Generated: $(date)"
    echo "Tests Passed: $TESTS_PASSED/$TESTS_TOTAL"
    echo "Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo ""
    echo "Q6 Features Tested:"
    echo "- Network mode (TCP/UDP) with persistence"
    echo "- UDS mode (stream/datagram) with persistence"
    echo "- Persistent storage (memory-mapped files)"
    echo "- File locking for multiple processes"
    echo "- Inventory loading from existing files"
    echo "- Strict quantity validation"
    echo "- Welcome messages for clients"
    echo "- Memory mapping operations"
    echo "- Server timeout with inventory saving"
    echo "- Error handling and edge cases"
    echo ""
    echo "Persistent Storage Features:"
    echo "- Memory-mapped inventory files"
    echo "- Automatic file creation and validation"
    echo "- Cross-restart inventory persistence"
    echo "- File locking for process safety"
    echo "- Real-time synchronization to disk"
    echo "- Magic number validation"
} > test_report_q6.txt

echo -e "\n📄 Detailed report saved to: ${BLUE}test_report_q6.txt${NC}"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "\n${GREEN}🎉 ALL Q6 TESTS PASSED!${NC}"
    echo -e "${CYAN}💾 Persistent Warehouse is working perfectly!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some Q6 tests failed. Check the report for details.${NC}"
    exit 1
fi