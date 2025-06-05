#!/bin/bash

# q6_client_gcov.sh - Synchronized Client-side GCOV maximization script  
# Run this in Terminal 2 AFTER starting server script

echo "📱 Q6 CLIENT GCOV MAXIMIZATION SCRIPT (Synchronized)"
echo "================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TEST_DIR="/tmp/q6_gcov_test"
SYNC_DIR="$TEST_DIR/sync"

# Signal files for synchronization
READY_FILE="$SYNC_DIR/server_ready"
CLIENT_DONE_FILE="$SYNC_DIR/client_done"
PHASE_FILE="$SYNC_DIR/current_phase"

# Function to wait for server ready signal
wait_for_server() {
    local timeout="${1:-30}"
    
    echo -e "${CYAN}⏳ Waiting for server to be ready...${NC}"
    
    local count=0
    while [ $count -lt $timeout ]; do
        if [ -f "$READY_FILE" ]; then
            local phase=$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")
            echo -e "${GREEN}✅ Server ready for phase: $phase${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    echo -e "${RED}⏰ Timeout waiting for server${NC}"
    return 1
}

# Function to signal client completion
signal_done() {
    touch "$CLIENT_DONE_FILE"
    echo -e "${GREEN}✅ Phase completed, signaling server${NC}"
}

# Function to run client tests with timeout protection
run_client_test() {
    local description="$1"
    local timeout="$2"
    shift 2
    
    echo -e "${BLUE}🧪 $description${NC}"
    
    # Run the command with timeout
    timeout "$timeout" "$@" || {
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo -e "${YELLOW}⚠️  Test timed out after ${timeout}s (this is expected)${NC}"
        else
            echo -e "${YELLOW}⚠️  Test exited with code $exit_code${NC}"
        fi
    }
}

echo -e "${CYAN}💡 This script will automatically sync with the server script${NC}"
echo -e "${CYAN}🔄 Testing will begin when server phases are ready${NC}"

# Test client error paths first (no server needed)
echo -e "\n${YELLOW}📋 Client Error Path Testing${NC}"
echo "Testing client argument validation..."

timeout 2s ./persistent_requester >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -h localhost >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -p 12345 >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -h localhost -p 0 >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -h localhost -p 99999 >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -h localhost -p 12345 -u 12345 >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -h localhost -p 12345 -f /tmp/test.sock >/dev/null 2>&1 || true
timeout 2s ./persistent_requester -f /tmp/nonexistent.sock >/dev/null 2>&1 || true
timeout 2s ./persistent_requester --help >/dev/null 2>&1 || true

echo -e "${GREEN}✅ Client error testing complete${NC}"

# Main synchronization loop
while true; do
    if ! wait_for_server; then
        echo -e "${RED}❌ Server not responding, exiting${NC}"
        exit 1
    fi
    
    phase=$(cat "$PHASE_FILE" 2>/dev/null || echo "unknown")
    
    case "$phase" in
        "network_mode")
            echo -e "\n${YELLOW}📋 Testing Network Mode${NC}"
            
            # Test comprehensive interactive client
            run_client_test "Interactive client (full menu)" 15s bash -c '
                {
                    echo "1"; echo "1"; echo "500"; echo "2"; echo "750"; echo "3"; echo "1200"; echo "4"
                    echo "2"; echo "1"; echo "10"; echo "2"; echo "5"; echo "3"; echo "3"; echo "4"; echo "2"; echo "5"
                    echo "3"
                } | ./persistent_requester -h localhost -p 42001 -u 42002'
            
            # Test input validation
            run_client_test "Input validation testing" 10s bash -c '
                {
                    echo "invalid"; echo "1"; echo "invalid"; echo "5"; echo "1"
                    echo "invalid"; echo "0"; echo "999999999999999999999"; echo "100"; echo "4"; echo "3"
                } | ./persistent_requester -h localhost -p 42001 -u 42002'
            
            # Test direct network commands
            run_client_test "Direct TCP commands" 5s bash -c '
                echo "ADD CARBON 100" | nc localhost 42001'
            
            run_client_test "Direct UDP commands" 5s bash -c '
                echo "DELIVER WATER 5" | nc -u localhost 42002'
            
            signal_done
            ;;
            
        "uds_mode")
            echo -e "\n${YELLOW}📋 Testing UDS Mode${NC}"
            
            run_client_test "UDS interactive client" 15s bash -c '
                {
                    echo "1"; echo "1"; echo "200"; echo "2"; echo "300"; echo "3"; echo "400"; echo "4"
                    echo "2"; echo "1"; echo "10"; echo "5"; echo "3"
                } | ./persistent_requester -f '"$TEST_DIR/stream.sock"' -d '"$TEST_DIR/datagram.sock"
            
            signal_done
            ;;
            
        "persistence_phase1")
            echo -e "\n${YELLOW}📋 Testing Persistence Phase 1${NC}"
            
            run_client_test "Adding atoms to persistent inventory" 8s bash -c '
                echo "ADD CARBON 250" | nc localhost 42003'
            
            run_client_test "Interactive persistence test" 10s bash -c '
                {
                    echo "1"; echo "2"; echo "500"; echo "3"; echo "1000"; echo "4"; echo "3"
                } | ./persistent_requester -h localhost -p 42003'
            
            signal_done
            ;;
            
        "persistence_phase2")
            echo -e "\n${YELLOW}📋 Testing Persistence Phase 2 (Loading)${NC}"
            
            run_client_test "Testing loaded inventory" 8s bash -c '
                echo "ADD HYDROGEN 300" | nc localhost 42004'
            
            run_client_test "Verifying persistence" 8s bash -c '
                {
                    echo "1"; echo "1"; echo "100"; echo "4"; echo "3"
                } | ./persistent_requester -h localhost -p 42004'
            
            signal_done
            ;;
            
        "timeout_mode")
            echo -e "\n${YELLOW}📋 Testing Timeout Mode (Quick!)${NC}"
            
            run_client_test "Quick test before timeout" 5s bash -c '
                {
                    echo "1"; echo "1"; echo "50"; echo "4"; echo "3"
                } | ./persistent_requester -h localhost -p 42005 -u 42006'
            
            signal_done
            ;;
            
        "uds_stream_only")
            echo -e "\n${YELLOW}📋 Testing UDS Stream Only${NC}"
            
            run_client_test "Stream-only client (no datagram)" 10s bash -c '
                {
                    echo "1"; echo "1"; echo "50"; echo "4"
                    echo "2"; echo "3"
                } | ./persistent_requester -f '"$TEST_DIR/stream_only.sock"
            
            signal_done
            ;;
            
        "COMPLETE")
            echo -e "\n${GREEN}🎉 All phases complete!${NC}"
            break
            ;;
            
        *)
            echo -e "${YELLOW}⏳ Waiting for known phase... (current: $phase)${NC}"
            sleep 2
            ;;
    esac
    
    sleep 1
done

echo -e "\n${GREEN}✨ Client GCOV maximization complete!${NC}"
echo -e "${CYAN}📊 Coverage testing finished successfully!${NC}"