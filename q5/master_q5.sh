#!/bin/bash

# master_q5.sh - סקריפט מאסטר לניהול כל בדיקות Q5

echo "🚀 Q5 MASTER TEST CONTROLLER (UDS + Network)"
echo "============================================="

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
    
    echo "🔍 Checking Q5 files..."
    
    for file in q5_full_test.sh q5_integrated_test.sh run_q5_server.sh run_q5_client.sh; do
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
    chmod +x q5_full_test.sh q5_integrated_test.sh run_q5_server.sh run_q5_client.sh 2>/dev/null
    echo -e "${GREEN}✅ All Q5 files ready${NC}"
}

show_main_menu() {
    echo -e "\n${CYAN}🎯 Choose Q5 testing mode:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}AUTOMATIC TESTING:${NC}"
    echo "  1. 🤖 Full automatic test suite (UDS + Network)"
    echo "  2. 🔄 Integrated server+client tests (All modes)"
    echo "  3. 🏗️  Build and quick validation only"
    echo ""
    echo -e "${YELLOW}MANUAL TESTING:${NC}"
    echo "  4. 🖥️  Start server in this terminal"
    echo "  5. 💻 Start client in this terminal"
    echo "  6. 📋 Instructions for parallel testing (2 terminals)"
    echo ""
    echo -e "${YELLOW}MODE-SPECIFIC TESTS:${NC}"
    echo "  7. 🌐 Network mode tests only (TCP/UDP)"
    echo "  8. 🔌 UDS mode tests only (Stream/Datagram)"
    echo "  9. 🔀 Mixed mode tests only"
    echo ""
    echo -e "${YELLOW}UTILITIES:${NC}"
    echo " 10. 🧹 Clean all sockets and test files"
    echo " 11. 📊 Show last test results"
    echo " 12. ❓ Help and Q5 documentation"
    echo " 13. 🚪 Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Choice: "
}

quick_build() {
    echo -e "\n${BLUE}📦 Building Q5...${NC}"
    if make clean > /dev/null 2>&1 && make all > build_q5.log 2>&1; then
        echo -e "${GREEN}✅ Build successful${NC}"
        return 0
    else
        echo -e "${RED}❌ Build failed!${NC}"
        echo "Build log:"
        cat build_q5.log
        return 1
    fi
}

quick_validation() {
    echo -e "\n${BLUE}🔍 Quick Q5 validation...${NC}"
    
    # בדיקת שרת
    if ./uds_warehouse > /dev/null 2>&1; then
        echo -e "${RED}❌ Server should fail without arguments${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Server correctly rejects invalid arguments${NC}"
    fi
    
    # בדיקת לקוח
    if ./uds_requester > /dev/null 2>&1; then
        echo -e "${RED}❌ Client should fail without arguments${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Client correctly rejects invalid arguments${NC}"
    fi
    
    echo -e "${GREEN}✅ Quick Q5 validation passed${NC}"
    return 0
}

cleanup_all() {
    echo -e "\n${BLUE}🧹 Cleaning up Q5 files and sockets...${NC}"
    
    # הרג תהליכי שרת
    pkill -f uds_warehouse 2>/dev/null || true
    
    # ניקוי socket files
    rm -f /tmp/stream*.sock /tmp/datagram*.sock /tmp/test_*.sock 2>/dev/null
    
    # ניקוי קבצי לוג ובדיקות
    rm -f server_*.log client_*.log *.log test_results_q5.log test_report_q5.txt build_q5.log
    
    echo -e "${GREEN}✅ Q5 cleanup completed${NC}"
}

show_parallel_instructions() {
    echo -e "\n${CYAN}📋 Q5 Parallel Testing Instructions${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}🖥️  TERMINAL 1 (Server):${NC}"
    echo "   ./run_q5_server.sh"
    echo "   - Choose server mode (Network/UDS/Mixed)"
    echo "   - Server will display connection details"
    echo "   - Try typing server commands like 'GEN SOFT DRINK'"
    echo ""
    echo -e "${YELLOW}💻 TERMINAL 2 (Client):${NC}"
    echo "   ./run_q5_client.sh"
    echo "   - Choose matching client configuration"
    echo "   - Test both atom addition and molecule requests"
    echo ""
    echo -e "${YELLOW}🎯 Q5 Specific Testing Scenarios:${NC}"
    echo ""
    echo -e "${BLUE}Network Mode Testing:${NC}"
    echo "   Terminal 1: Server option 1 (Basic Network)"
    echo "   Terminal 2: Client option 1 (Connect to Basic Network)"
    echo ""
    echo -e "${BLUE}UDS Mode Testing:${NC}"
    echo "   Terminal 1: Server option 4 (Basic UDS)"
    echo "   Terminal 2: Client option 4 (Connect to Basic UDS)"
    echo ""
    echo -e "${BLUE}Mixed Mode Testing:${NC}"
    echo "   Terminal 1: Server option 7 (Network TCP + UDS datagram)"
    echo "   Terminal 2: Client with custom connection"
    echo ""
    echo -e "${GREEN}💡 Q5 Pro Tips:${NC}"
    echo "   • UDS sockets are created in /tmp/ directory"
    echo "   • Network ports start from 30001 to avoid conflicts"
    echo "   • Mixed mode allows TCP+UDS or UDS+UDP combinations"
    echo "   • Use auto-test options (7-8) for automated testing"
    echo "   • Check that socket files exist before connecting"
    echo "   • UDS is faster than network for local communication"
}

show_help() {
    echo -e "\n${CYAN}❓ Q5 Testing Help (UDS + Network)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}📁 Q5 File Structure:${NC}"
    echo "   uds_warehouse.c        - Q5 Server (UDS + Network support)"
    echo "   uds_requester.c        - Q5 Client (UDS + Network support)"
    echo "   Makefile               - Build configuration"
    echo "   q5_full_test.sh        - Automatic test suite"
    echo "   q5_integrated_test.sh  - Integrated server+client tests"
    echo "   run_q5_server.sh       - Server launcher"
    echo "   run_q5_client.sh       - Client launcher"
    echo ""
    echo -e "${YELLOW}🔧 Q5 Build Commands:${NC}"
    echo "   make clean             - Clean build files"
    echo "   make all               - Build both programs"
    echo "   make clean-sockets     - Remove UDS socket files"
    echo ""
    echo -e "${YELLOW}🧪 Q5 Test Types:${NC}"
    echo "   Network Mode  - TCP for atoms, UDP for molecules"
    echo "   UDS Mode      - Unix sockets (stream + datagram)"
    echo "   Mixed Mode    - Combination of network and UDS"
    echo "   Automatic     - Tests all modes without interaction"
    echo "   Integrated    - Server+client together (like Q4)"
    echo ""
    echo -e "${YELLOW}🎯 Q5 What Gets Tested:${NC}"
    echo "   • Network communication (TCP/UDP)"
    echo "   • UDS communication (stream/datagram)"
    echo "   • Mixed mode combinations"
    echo "   • Argument validation for both modes"
    echo "   • Socket file creation and cleanup"
    echo "   • Enhanced client feedback (SUCCESS/ERROR)"
    echo "   • Strict quantity validation (no defaults)"
    echo "   • Multiple client support"
    echo ""
    echo -e "${YELLOW}🔌 Q5 UDS Specifics:${NC}"
    echo "   • Stream sockets  - For reliable atom addition (like TCP)"
    echo "   • Datagram sockets - For molecule requests (like UDP)"
    echo "   • Socket files created in /tmp/ directory"
    echo "   • Automatic cleanup on server shutdown"
    echo "   • Better performance than network for local communication"
    echo ""
    echo -e "${YELLOW}🚨 Q5 Common Issues:${NC}"
    echo "   'Socket file not found'    - Start UDS server first"
    echo "   'Address already in use'   - Run cleanup (option 10)"
    echo "   'Permission denied'        - Check /tmp permissions"
    echo "   'Connection refused'       - Check server is running"
    echo "   Mixed mode confusion       - Read server output carefully"
}

run_network_tests() {
    echo -e "\n${BLUE}🌐 Running Network Mode Tests Only${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    # הפעל שרת network לבדיקות
    ./uds_warehouse -T 35001 -U 35002 -c 1000 -o 1000 -H 1000 > network_test_server.log 2>&1 &
    local server_pid=$!
    
    echo "Starting network test server..."
    sleep 2
    
    if ! kill -0 $server_pid 2>/dev/null; then
        echo -e "${RED}❌ Network test server failed to start${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Network test server started on TCP:35001, UDP:35002${NC}"
    echo "Now test with: ./run_q5_client.sh"
    echo "Or run automatic test: echo '1\n1\n100\n4\n2\n1\n5\n5\n3' | ./uds_requester -h localhost -p 35001 -u 35002"
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
    ./uds_warehouse -s /tmp/test_stream.sock -d /tmp/test_datagram.sock -c 500 -o 500 -H 500 > uds_test_server.log 2>&1 &
    local server_pid=$!
    
    echo "Starting UDS test server..."
    sleep 2
    
    if [ ! -S "/tmp/test_stream.sock" ]; then
        echo -e "${RED}❌ UDS test server failed to start${NC}"
        kill $server_pid 2>/dev/null || true
        return 1
    fi
    
    echo -e "${GREEN}✅ UDS test server started${NC}"
    echo "Socket files: /tmp/test_stream.sock, /tmp/test_datagram.sock"
    echo "Now test with: ./run_q5_client.sh"
    echo "Or run automatic test: echo '1\n1\n100\n4\n2\n1\n3\n5\n3' | ./uds_requester -f /tmp/test_stream.sock -d /tmp/test_datagram.sock"
    echo ""
    echo -e "${RED}Press Enter when done testing...${NC}"
    read
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    cleanup_all
    echo -e "${GREEN}UDS tests completed${NC}"
}

run_mixed_tests() {
    echo -e "\n${BLUE}🔀 Running Mixed Mode Tests Only${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! quick_build; then
        return 1
    fi
    
    cleanup_all
    
    echo -e "${YELLOW}Testing TCP + UDS datagram combination...${NC}"
    
    # הפעל שרת mixed mode
    ./uds_warehouse -T 35003 -d /tmp/mixed_datagram.sock -c 200 -o 200 -H 200 > mixed_test_server.log 2>&1 &
    local server_pid=$!
    
    echo "Starting mixed mode test server..."
    sleep 2
    
    if ! kill -0 $server_pid 2>/dev/null || [ ! -S "/tmp/mixed_datagram.sock" ]; then
        echo -e "${RED}❌ Mixed mode test server failed to start${NC}"
        kill $server_pid 2>/dev/null || true
        return 1
    fi
    
    echo -e "${GREEN}✅ Mixed mode test server started${NC}"
    echo "TCP port: 35003, UDS datagram: /tmp/mixed_datagram.sock"
    echo "Test with: ./uds_requester -h localhost -p 35003 -d /tmp/mixed_datagram.sock"
    echo ""
    echo -e "${RED}Press Enter when done testing...${NC}"
    read
    
    kill $server_pid 2>/dev/null
    wait $server_pid 2>/dev/null || true
    cleanup_all
    echo -e "${GREEN}Mixed mode tests completed${NC}"
}

show_last_results() {
    echo -e "\n${BLUE}📊 Last Q5 Test Results${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -f "test_report_q5.txt" ]; then
        echo -e "${YELLOW}=== Standard Test Results ===${NC}"
        cat test_report_q5.txt
    fi
    
    if [ -f "integrated_test_report_q5.txt" ]; then
        echo -e "\n${YELLOW}=== Integrated Test Results ===${NC}"
        cat integrated_test_report_q5.txt
    fi
    
    if [ ! -f "test_report_q5.txt" ] && [ ! -f "integrated_test_report_q5.txt" ]; then
        echo -e "${YELLOW}No previous Q5 test results found${NC}"
        echo "Run automatic tests first (option 1 or 2)"
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
            echo -e "\n${GREEN}🤖 Running Full Q5 Automatic Test Suite${NC}"
            ./q5_full_test.sh
            ;;
        2)
            echo -e "\n${GREEN}🔄 Running Integrated Server+Client Tests${NC}"
            ./q5_integrated_test.sh
            ;;
        3)
            quick_build && quick_validation
            ;;
        4)
            echo -e "\n${GREEN}🖥️  Starting Q5 Server Mode${NC}"
            ./run_q5_server.sh
            ;;
        5)
            echo -e "\n${GREEN}💻 Starting Q5 Client Mode${NC}"
            ./run_q5_client.sh
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
            run_mixed_tests
            ;;
        10)
            cleanup_all
            ;;
        11)
            show_last_results
            ;;
        12)
            show_help
            ;;
        13)
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