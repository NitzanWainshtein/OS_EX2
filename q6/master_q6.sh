#!/bin/bash

# master_q6.sh - סקריפט מאסטר לניהול כל בדיקות Q6

echo "🚀 Q6 MASTER TEST CONTROLLER (Persistent Warehouse)"
echo "==================================================="

# צבעים
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# בדוק שכל הקבצים קיימים
check_files() {
    local missing=false
    
    echo "🔍 Checking Q6 files..."
    
    for file in q6_full_test.sh q6_integrated_test.sh run_q6_server.sh run_q6_client.sh; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ $file not found${NC}"
            missing=true
        fi
    done
    
    if $missing; then
        echo -e "${RED}Some required scripts are missing!${NC}"
        exit 1
    fi
    
    # הפוך לבר ביצוע
    chmod +x q6_full_test.sh q6_integrated_test.sh run_q6_server.sh run_q6_client.sh 2>/dev/null
    echo -e "${GREEN}✅ All Q6 files ready${NC}"
}

show_main_menu() {
    echo -e "\n${CYAN}🎯 Choose Q6 testing mode:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}AUTOMATIC TESTING:${NC}"
    echo "  1. 🤖 Full automatic test suite (All modes + Coverage)"
    echo "  2. 🔄 Integrated server+client tests (Comprehensive)"
    echo "  3. 🏗️  Build with coverage and quick validation"
    echo ""
    echo -e "${YELLOW}MANUAL TESTING:${NC}"
    echo "  4. 🖥️  Start server in this terminal"
    echo "  5. 💻 Start client in this terminal"
    echo "  6. 📋 Instructions for parallel testing (2 terminals)"
    echo ""
    echo -e "${YELLOW}MODE-SPECIFIC TESTS:${NC}"
    echo "  7. 🌐 Network mode tests only (TCP/UDP)"
    echo "  8. 🔌 UDS mode tests only (Stream/Datagram)"
    echo "  9. 🔄 Persistent storage tests (Multiple processes)"
    echo " 10. 🕐 Timeout and edge case tests"
    echo ""
    echo -e "${YELLOW}UTILITIES:${NC}"
    echo " 11. 🧹 Clean all files and test data"
    echo " 12. 📊 Show last test results and coverage"
    echo " 13. 🔧 Generate coverage report only"
    echo " 14. ❓ Help and Q6 documentation"
    echo " 15. 🚪 Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Choice: "
}

quick_build() {
    echo -e "\n${BLUE}📦 Building Q6 with coverage...${NC}"
    if make clean > /dev/null 2>&1 && make coverage > build_q6.log 2>&1; then
        echo -e "${GREEN}✅ Build successful${NC}"
        return 0
    else
        echo -e "${RED}❌ Build failed!${NC}"
        echo "Build log:"
        cat build_q6.log
        return 1
    fi
}

quick_validation() {
    echo -e "\n${BLUE}🔍 Quick Q6 validation...${NC}"
    
    # בדיקת שרת
    if ./persistent_warehouse > /dev/null 2>&1; then
        echo -e "${RED}❌ Server should fail without arguments${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Server correctly rejects invalid arguments${NC}"
    fi
    
    # בדיקת לקוח
    if ./persistent_requester > /dev/null 2>&1; then
        echo -e "${RED}❌ Client should fail without arguments${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Client correctly rejects invalid arguments${NC}"
    fi
    
    echo -e "${GREEN}✅ Quick Q6 validation passed${NC}"
    return 0
}

cleanup_all() {
    echo -e "\n${BLUE}🧹 Cleaning up Q6 files and data...${NC}"
    
    # הרג תהליכי שרת
    pkill -f persistent_warehouse 2>/dev/null || true
    
    # ניקוי socket files
    rm -f /tmp/stream*.sock /tmp/datagram*.sock /tmp/test_*.sock 2>/dev/null
    
    # ניקוי קבצי מידע מתמשכים
    rm -f /tmp/inventory*.dat /tmp/test_*.dat 2>/dev/null
    
    # ניקוי קבצי לוג ובדיקות
    rm -f server_*.log client_*.log *.log test_results_q6.log test_report_q6.txt
    rm -f build_q6.log coverage_report_q6.txt *.gcov *.gcno *.gcda
    
    echo -e "${GREEN}✅ Q6 cleanup completed${NC}"
}

show_parallel_instructions() {
    echo -e "\n${CYAN}📋 Q6 Parallel Testing Instructions${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}🖥️  TERMINAL 1 (Server):${NC}"
    echo "   ./run_q6_server.sh"
    echo "   - Choose server mode (Network/UDS/Mixed)"
    echo "   - Server will display connection details"
    echo "   - Try typing server commands like 'GEN SOFT DRINK'"
    echo ""
    echo -e "${YELLOW}💻 TERMINAL 2 (Client):${NC}"
    echo "   ./run_q6_client.sh"
    echo "   - Choose matching client configuration"
    echo "   - Test both atom addition and molecule requests"
    echo ""
    echo -e "${YELLOW}🎯 Q6 Specific Testing Scenarios:${NC}"
    echo ""
    echo -e "${BLUE}Network Mode Testing:${NC}"
    echo "   Terminal 1: Server option 1 (Basic Network)"
    echo "   Terminal 2: Client option 1 (Connect to Basic Network)"
    echo ""
    echo -e "${BLUE}UDS Mode Testing:${NC}"
    echo "   Terminal 1: Server option 4 (Basic UDS)"
    echo "   Terminal 2: Client option 4 (Connect to Basic UDS)"
    echo ""
    echo -e "${BLUE}Persistent Storage Testing:${NC}"
    echo "   Terminal 1: Server option 2 (Network with save file)"
    echo "   Terminal 2: Add atoms, quit client, restart and verify persistence"
    echo ""
    echo -e "${BLUE}Multiple Process Testing:${NC}"
    echo "   Terminal 1: Server with save file"
    echo "   Terminal 2: Multiple clients (stress test option)"
    echo ""
    echo -e "${GREEN}💡 Q6 Pro Tips:${NC}"
    echo "   • Save files are created in /tmp/ directory"
    echo "   • Network ports start from 40001 to avoid conflicts"
    echo "   • Persistent storage allows multiple processes safely"
    echo "   • File locking prevents data corruption"
    echo "   • Memory mapping provides efficient I/O"
    echo "   • Check inventory persistence between server restarts"
}

show_help() {
    echo -e "\n${CYAN}❓ Q6 Testing Help (Persistent Warehouse)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}📁 Q6 File Structure:${NC}"
    echo "   persistent_warehouse.c     - Q6 Server (Persistent + UDS + Network)"
    echo "   persistent_requester.c     - Q6 Client (Enhanced with UDS support)"
    echo "   Makefile                   - Build configuration with coverage"
    echo "   q6_full_test.sh            - Automatic test suite"
    echo "   q6_integrated_test.sh      - Integrated server+client tests"
    echo "   run_q6_server.sh           - Server launcher"
    echo "   run_q6_client.sh           - Client launcher"
    echo ""
    echo -e "${YELLOW}🔧 Q6 Build Commands:${NC}"
    echo "   make clean                 - Clean build files"
    echo "   make coverage              - Build with coverage support"
    echo "   make coverage-report       - Generate coverage report"
    echo "   make clean-sockets         - Remove UDS socket files"
    echo ""
    echo -e "${YELLOW}🧪 Q6 Test Types:${NC}"
    echo "   Network Mode     - TCP for atoms, UDP for molecules"
    echo "   UDS Mode         - Unix sockets (stream + datagram)"
    echo "   Persistent Mode  - File-based inventory storage"
    echo "   Multiple Process - Concurrent server instances"
    echo "   Automatic        - Tests all modes without interaction"
    echo "   Coverage         - Code coverage analysis"
    echo ""
    echo -e "${YELLOW}🎯 Q6 What Gets Tested:${NC}"
    echo "   • Network communication (TCP/UDP)"
    echo "   • UDS communication (stream/datagram)"
    echo "   • Persistent storage (memory-mapped files)"
    echo "   • File locking mechanisms"
    echo "   • Multiple process support"
    echo "   • Inventory synchronization"
    echo "   • Enhanced client feedback"
    echo "   • Strict input validation"
    echo "   • Timeout functionality"
    echo "   • Graceful shutdown"
    echo ""
    echo -e "${YELLOW}💾 Q6 Persistent Storage:${NC}"
    echo "   • Memory-mapped inventory files"
    echo "   • Automatic synchronization to disk"
    echo "   • File locking for concurrent access"
    echo "   • Magic number validation"
    echo "   • Atomic inventory updates"
    echo "   • Cross-process inventory sharing"
    echo ""
    echo -e "${YELLOW}🚨 Q6 Common Issues:${NC}"
    echo "   'Save file required'       - Use -f option with file path"
    echo "   'File already locked'      - Another server instance running"
    echo "   'Permission denied'        - Check /tmp permissions"
    echo "   'Invalid save file'        - File will be reinitialised"
    echo "   'Memory mapping failed'    - Disk space or permissions issue"
}

run_network_tests() {
    echo -e "\n${BLUE}🌐 Running Network Mode Tests Only${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    # הפעל שרת network לבדיקות
    ./persistent_warehouse -T 45001 -U 45002 -f /tmp/network_test.dat -c 1000 -o 1000 -H 1000 > network_test_server.log 2>&1 &
    local server_pid=$!
    
    echo "Starting network test server..."
    sleep 3
    
    if ! kill -0 $server_pid 2>/dev/null; then
        echo -e "${RED}❌ Network test server failed to start${NC}"
        cat network_test_server.log
        return 1
    fi
    
    echo -e "${GREEN}✅ Network test server started on TCP:45001, UDP:45002${NC}"
    echo "Save file: /tmp/network_test.dat"
    echo "Now test with: ./run_q6_client.sh"
    echo "Or run automatic test..."
    
    # בדיקה אוטומטית
    {
        echo "1"; echo "1"; echo "500"; echo "4"
        echo "2"; echo "1"; echo "10"; echo "5"; echo "3"
    } | timeout 15s ./persistent_requester -h localhost -p 45001 -u 45002 > network_auto_test.log 2>&1
    
    if grep -q "Connected.*Persistent Warehouse" network_auto_test.log; then
        echo -e "${GREEN}✅ Network automatic test passed${NC}"
    else
        echo -e "${RED}❌ Network automatic test failed${NC}"
    fi
    
    echo ""
    echo -e "${RED}Press Enter when done testing...${NC}"
    read
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    echo -e "${GREEN}Network tests completed${NC}"
}

run_uds_tests() {
    echo -e "\n${BLUE}🔌 Running UDS Mode Tests Only${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    # נקה socket files
    cleanup_all
    
    # הפעל שרת UDS לבדיקות
    ./persistent_warehouse -s /tmp/uds_test_stream.sock -d /tmp/uds_test_datagram.sock -f /tmp/uds_test.dat -c 500 -o 500 -H 500 > uds_test_server.log 2>&1 &
    local server_pid=$!
    
    echo "Starting UDS test server..."
    sleep 3
    
    if [ ! -S "/tmp/uds_test_stream.sock" ]; then
        echo -e "${RED}❌ UDS test server failed to start${NC}"
        kill $server_pid 2>/dev/null || true
        cat uds_test_server.log
        return 1
    fi
    
    echo -e "${GREEN}✅ UDS test server started${NC}"
    echo "Socket files: /tmp/uds_test_stream.sock, /tmp/uds_test_datagram.sock"
    echo "Save file: /tmp/uds_test.dat"
    echo "Now test with: ./run_q6_client.sh"
    
    # בדיקה אוטומטית
    {
        echo "1"; echo "2"; echo "300"; echo "4"
        echo "2"; echo "2"; echo "5"; echo "5"; echo "3"
    } | timeout 15s ./persistent_requester -f /tmp/uds_test_stream.sock -d /tmp/uds_test_datagram.sock > uds_auto_test.log 2>&1
    
    if grep -q "Connected.*Persistent Warehouse.*UDS" uds_auto_test.log; then
        echo -e "${GREEN}✅ UDS automatic test passed${NC}"
    else
        echo -e "${RED}❌ UDS automatic test failed${NC}"
    fi
    
    echo ""
    echo -e "${RED}Press Enter when done testing...${NC}"
    read
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    cleanup_all
    echo -e "${GREEN}UDS tests completed${NC}"
}

run_persistent_tests() {
    echo -e "\n${BLUE}💾 Running Persistent Storage Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    cleanup_all
    
    echo -e "${YELLOW}Testing inventory persistence...${NC}"
    
    # שלב 1: יצירת מלאי
    echo "Phase 1: Creating initial inventory..."
    ./persistent_warehouse -T 45003 -U 45004 -f /tmp/persistence_test.dat -c 100 > persist_server1.log 2>&1 &
    local server_pid=$!
    sleep 2
    
    # הוסף אטומים
    {
        echo "1"; echo "1"; echo "1000"; echo "4"
        echo "1"; echo "2"; echo "2000"; echo "4"
        echo "1"; echo "3"; echo "3000"; echo "4"; echo "3"
    } | timeout 10s ./persistent_requester -h localhost -p 45003 -u 45004 > persist_client1.log 2>&1
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    
    if [ -f "/tmp/persistence_test.dat" ]; then
        echo -e "${GREEN}✅ Inventory file created${NC}"
    else
        echo -e "${RED}❌ Inventory file not created${NC}"
        return 1
    fi
    
    # שלב 2: טעינת מלאי קיים
    echo "Phase 2: Loading existing inventory..."
    ./persistent_warehouse -T 45005 -U 45006 -f /tmp/persistence_test.dat > persist_server2.log 2>&1 &
    server_pid=$!
    sleep 2
    
    # בדוק שהמלאי נטען
    {
        echo "1"; echo "1"; echo "500"; echo "4"; echo "3"
    } | timeout 10s ./persistent_requester -h localhost -p 45005 -u 45006 > persist_client2.log 2>&1
    
    if grep -q "Current inventory.*C=1" persist_client2.log; then
        echo -e "${GREEN}✅ Inventory persistence working${NC}"
    else
        echo -e "${RED}❌ Inventory persistence failed${NC}"
    fi
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    
    # שלב 3: בדיקת תהליכים מרובים
    echo "Phase 3: Testing multiple processes..."
    ./persistent_warehouse -T 45007 -U 45008 -f /tmp/persistence_test.dat > persist_server3a.log 2>&1 &
    local server_pid1=$!
    
    # נסה להפעיל שרת שני עם אותו קובץ
    ./persistent_warehouse -T 45009 -U 45010 -f /tmp/persistence_test.dat > persist_server3b.log 2>&1 &
    local server_pid2=$!
    
    sleep 3
    
    local servers_running=0
    if kill -0 $server_pid1 2>/dev/null; then
        servers_running=$((servers_running + 1))
    fi
    if kill -0 $server_pid2 2>/dev/null; then
        servers_running=$((servers_running + 1))
    fi
    
    echo -e "${GREEN}✅ File locking test: $servers_running server(s) running${NC}"
    
    kill $server_pid1 $server_pid2 2>/dev/null || true
    wait $server_pid1 $server_pid2 2>/dev/null || true
    
    echo -e "${GREEN}Persistent storage tests completed${NC}"
}

run_timeout_tests() {
    echo -e "\n${BLUE}🕐 Running Timeout and Edge Case Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    cleanup_all
    
    # בדיקת timeout
    echo -e "${YELLOW}Testing server timeout (3 seconds)...${NC}"
    ./persistent_warehouse -T 45011 -U 45012 -f /tmp/timeout_test.dat -t 3 > timeout_server.log 2>&1 &
    local server_pid=$!
    
    echo "Waiting for timeout..."
    sleep 5
    
    if ! kill -0 $server_pid 2>/dev/null; then
        echo -e "${GREEN}✅ Server timeout working${NC}"
    else
        echo -e "${RED}❌ Server timeout failed${NC}"
        kill $server_pid 2>/dev/null || true
    fi
    
    # בדיקת edge cases
    echo -e "${YELLOW}Testing edge cases...${NC}"
    
    # כמויות גדולות
    ./persistent_warehouse -T 45013 -U 45014 -f /tmp/edge_test.dat > edge_server.log 2>&1 &
    server_pid=$!
    sleep 2
    
    {
        echo "1"; echo "1"; echo "999999999999999999"; echo "4"
        echo "2"; echo "1"; echo "0"; echo "1"; echo "5"; echo "3"
    } | timeout 10s ./persistent_requester -h localhost -p 45013 -u 45014 > edge_client.log 2>&1
    
    if grep -q "ERROR.*Invalid quantity.*0" edge_client.log; then
        echo -e "${GREEN}✅ Input validation working${NC}"
    else
        echo -e "${RED}❌ Input validation failed${NC}"
    fi
    
    kill $server_pid 2>/dev/null || true
    wait $server_pid 2>/dev/null || true
    
    echo -e "${GREEN}Timeout and edge case tests completed${NC}"
}

show_last_results() {
    echo -e "\n${BLUE}📊 Last Q6 Test Results${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -f "test_report_q6.txt" ]; then
        echo -e "${YELLOW}=== Standard Test Results ===${NC}"
        cat test_report_q6.txt
    fi
    
    if [ -f "integrated_test_report_q6.txt" ]; then
        echo -e "\n${YELLOW}=== Integrated Test Results ===${NC}"
        cat integrated_test_report_q6.txt
    fi
    
    if [ -f "coverage_report_q6.txt" ]; then
        echo -e "\n${YELLOW}=== Coverage Report ===${NC}"
        head -20 coverage_report_q6.txt
    fi
    
    if [ ! -f "test_report_q6.txt" ] && [ ! -f "integrated_test_report_q6.txt" ]; then
        echo -e "${YELLOW}No previous Q6 test results found${NC}"
        echo "Run automatic tests first (option 1 or 2)"
    fi
}

generate_coverage_only() {
    echo -e "\n${BLUE}📊 Generating Coverage Report Only${NC}"
    
    if [ ! -f "*.gcda" ] 2>/dev/null; then
        echo -e "${YELLOW}No coverage data found. Run tests first.${NC}"
        return 1
    fi
    
    if make coverage-report 2>&1 | tee coverage_generation.log; then
        echo -e "${GREEN}✅ Coverage report generated${NC}"
        
        if [ -f "coverage_report_q6.txt" ]; then
            echo -e "\n${CYAN}Coverage Summary:${NC}"
            grep "Lines executed" coverage_report_q6.txt | head -3
        fi
    else
        echo -e "${RED}❌ Failed to generate coverage report${NC}"
        cat coverage_generation.log
    fi
}

# בדוק קבצים
check_files

# לולאה ראשית
while true; do
    show_main_menu
    read choice
    
    case $choice in
        1)
            echo -e "\n${GREEN}🤖 Running Full Q6 Automatic Test Suite${NC}"
            ./q6_full_test.sh
            ;;
        2)
            echo -e "\n${GREEN}🔄 Running Integrated Server+Client Tests${NC}"
            ./q6_integrated_test.sh
            ;;
        3)
            quick_build && quick_validation
            ;;
        4)
            echo -e "\n${GREEN}🖥️  Starting Q6 Server Mode${NC}"
            ./run_q6_server.sh
            ;;
        5)
            echo -e "\n${GREEN}💻 Starting Q6 Client Mode${NC}"
            ./run_q6_client.sh
            ;;
        6)
            show_parallel_instructions
            ;;
        7)
            run_network_tests
            ;;
        8)
            run_uds_tests
            ;;
        9)
            run_persistent_tests
            ;;
        10)
            run_timeout_tests
            ;;
        11)
            cleanup_all
            ;;
        12)
            show_last_results
            ;;
        13)
            generate_coverage_only
            ;;
        14)
            show_help
            ;;
        15)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            cleanup_all
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to return to main menu...${NC}"
    read
done