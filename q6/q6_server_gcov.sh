#!/bin/bash

# q6_server_gcov.sh - Synchronized Server-side GCOV maximization script
# Run this in Terminal 1

echo "🖥️  Q6 SERVER GCOV MAXIMIZATION SCRIPT (Synchronized)"
echo "=================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TEST_DIR="/tmp/q6_gcov_test"
SYNC_DIR="$TEST_DIR/sync"
mkdir -p "$TEST_DIR" "$SYNC_DIR"

# Signal files for synchronization
READY_FILE="$SYNC_DIR/server_ready"
CLIENT_DONE_FILE="$SYNC_DIR/client_done"
PHASE_FILE="$SYNC_DIR/current_phase"

# Build with coverage
echo -e "${BLUE}🔨 Building with coverage...${NC}"
make clean >/dev/null 2>&1
if ! make all >/dev/null 2>&1; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Build successful${NC}"

cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    pkill -f persistent_warehouse 2>/dev/null || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Function to wait for client
wait_for_client() {
    local phase="$1"
    local timeout="${2:-30}"
    
    echo "$phase" > "$PHASE_FILE"
    touch "$READY_FILE"
    
    echo -e "${CYAN}⏳ Waiting for client to complete phase: $phase${NC}"
    
    local count=0
    while [ $count -lt $timeout ]; do
        if [ -f "$CLIENT_DONE_FILE" ]; then
            rm -f "$CLIENT_DONE_FILE" "$READY_FILE"
            echo -e "${GREEN}✅ Client completed phase: $phase${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    echo -e "${RED}⏰ Timeout waiting for client (${timeout}s)${NC}"
    rm -f "$CLIENT_DONE_FILE" "$READY_FILE"
    return 1
}

# Function to start server and wait for it
start_server_and_wait() {
    local cmd="$1"
    local check_type="$2"  # "port" or "socket"
    local check_value="$3"
    local phase="$4"
    
    echo -e "${BLUE}🚀 Starting: $cmd${NC}"
    
    # Start server in background
    eval "$cmd" &
    SERVER_PID=$!
    
    # Wait for server to be ready
    local ready=false
    local count=0
    while [ $count -lt 10 ]; do
        if [ "$check_type" = "port" ]; then
            if timeout 1s nc -z localhost "$check_value" 2>/dev/null; then
                ready=true
                break
            fi
        elif [ "$check_type" = "socket" ]; then
            if [ -S "$check_value" ]; then
                ready=true
                break
            fi
        fi
        sleep 1
        count=$((count + 1))
    done
    
    if [ "$ready" = "true" ]; then
        echo -e "${GREEN}✅ Server ready!${NC}"
        wait_for_client "$phase"
    else
        echo -e "${RED}❌ Server failed to start${NC}"
        kill $SERVER_PID 2>/dev/null || true
        return 1
    fi
    
    # Cleanup server
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    sleep 1
}

echo -e "\n${CYAN}🎯 This script will run synchronized server phases${NC}"
echo -e "${CYAN}💡 Start the client script in Terminal 2 now!${NC}"
sleep 3

echo -e "\n${YELLOW}📋 Phase 1: Server Error Testing${NC}"
echo "Testing argument validation (quick tests)..."

# Quick error tests that don't need client
timeout 2s ./persistent_warehouse >/dev/null 2>&1 || true
timeout 2s ./persistent_warehouse -T 0 -f test.dat >/dev/null 2>&1 || true
timeout 2s ./persistent_warehouse -T 99999 -f test.dat >/dev/null 2>&1 || true
timeout 2s ./persistent_warehouse -T 12345 -U 12345 -f test.dat >/dev/null 2>&1 || true
timeout 2s ./persistent_warehouse --help >/dev/null 2>&1 || true

echo -e "${GREEN}✅ Error testing complete${NC}"
sleep 2

echo -e "\n${YELLOW}📋 Phase 2: Network Server + Admin Commands${NC}"
start_server_and_wait \
    "./persistent_warehouse -T 42001 -U 42002 -f '$TEST_DIR/network.dat' -c 1000 -o 1000 -H 1000" \
    "port" "42001" "network_mode"

echo -e "\n${YELLOW}📋 Phase 3: UDS Server${NC}"
rm -f "$TEST_DIR/stream.sock" "$TEST_DIR/datagram.sock"
start_server_and_wait \
    "./persistent_warehouse -s '$TEST_DIR/stream.sock' -d '$TEST_DIR/datagram.sock' -f '$TEST_DIR/uds.dat' -c 500 -o 500 -H 500" \
    "socket" "$TEST_DIR/stream.sock" "uds_mode"

echo -e "\n${YELLOW}📋 Phase 4: Persistence Testing${NC}"
echo "Creating inventory with first server..."

# First server instance
./persistent_warehouse -T 42003 -f "$TEST_DIR/persist.dat" -c 100 >"$TEST_DIR/persist1.log" 2>&1 &
SERVER_PID=$!

# Wait for server to start
if timeout 5s sh -c 'while ! nc -z localhost 42003; do sleep 0.5; done'; then
    echo -e "${GREEN}✅ First server ready${NC}"
    wait_for_client "persistence_phase1"
    
    # Send shutdown to first server
    echo "shutdown" | timeout 3s nc localhost 42003 >/dev/null 2>&1 || true
fi

kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true
sleep 2

echo "Loading existing inventory with second server..."
start_server_and_wait \
    "./persistent_warehouse -T 42004 -f '$TEST_DIR/persist.dat'" \
    "port" "42004" "persistence_phase2"

echo -e "\n${YELLOW}📋 Phase 5: Timeout Server (Auto-shutdown)${NC}"
echo "Starting server with 8-second timeout..."

./persistent_warehouse -T 42005 -U 42006 -f "$TEST_DIR/timeout.dat" -t 8 >"$TEST_DIR/timeout.log" 2>&1 &
SERVER_PID=$!

if timeout 5s sh -c 'while ! nc -z localhost 42005; do sleep 0.5; done'; then
    echo -e "${GREEN}✅ Timeout server ready${NC}"
    wait_for_client "timeout_mode" 15  # Shorter timeout since server will auto-shutdown
fi

# Wait for server to timeout naturally
sleep 10
echo -e "${GREEN}✅ Server timed out automatically${NC}"

echo -e "\n${YELLOW}📋 Phase 6: File Corruption Testing${NC}"
echo "Testing corrupted file handling..."

echo "corrupted data" > "$TEST_DIR/corrupted.dat"
timeout 5s ./persistent_warehouse -T 42007 -f "$TEST_DIR/corrupted.dat" >"$TEST_DIR/corrupted.log" 2>&1 || true
echo -e "${GREEN}✅ Corruption test complete${NC}"

echo -e "\n${YELLOW}📋 Phase 7: UDS Stream Only${NC}"
rm -f "$TEST_DIR/stream_only.sock"
start_server_and_wait \
    "./persistent_warehouse -s '$TEST_DIR/stream_only.sock' -f '$TEST_DIR/stream_only.dat'" \
    "socket" "$TEST_DIR/stream_only.sock" "uds_stream_only"

echo -e "\n${GREEN}🎉 All server phases complete!${NC}"
echo -e "${CYAN}📊 Generating coverage report...${NC}"

# Generate coverage
gcov *.c 2>/dev/null || true
make coverage-report 2>/dev/null || true

echo -e "\n${GREEN}✨ Server GCOV maximization complete!${NC}"
echo -e "${BLUE}📄 Coverage files generated:${NC}"
ls -la *.gcov 2>/dev/null | head -5 || echo "No .gcov files found"

if [ -f "coverage_report_q6.txt" ]; then
    echo -e "\n${CYAN}📊 Coverage Summary:${NC}"
    grep "Lines executed" coverage_report_q6.txt 2>/dev/null || echo "Coverage data available in coverage_report_q6.txt"
fi

# Signal final completion
echo "COMPLETE" > "$PHASE_FILE"
touch "$READY_FILE"