#!/bin/bash

# q6_run_coverage.sh - Enhanced Master Runner (PRESERVES COVERAGE DATA)
# Orchestrates comprehensive coverage testing WITHOUT destroying previous data

echo "🎯 Q6 ENHANCED COVERAGE RUNNER (ACCUMULATIVE)"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check files
if [ ! -f "persistent_warehouse.c" ] || [ ! -f "persistent_requester.c" ]; then
    echo -e "${RED}Error: Source files not found!${NC}"
    exit 1
fi

if [ ! -f "q6_server_coverage.sh" ] || [ ! -f "q6_client_coverage.sh" ]; then
    echo -e "${RED}Error: Coverage scripts not found!${NC}"
    exit 1
fi

# Make executable
chmod +x q6_server_coverage.sh q6_client_coverage.sh

# PRESERVE coverage data - only clean processes, NOT coverage files
echo -e "${BLUE}Cleaning processes (preserving coverage data)...${NC}"
pkill -f persistent_warehouse 2>/dev/null
pkill -f persistent_requester 2>/dev/null
sleep 1

# CRITICAL FIX: NEVER rebuild if coverage data exists
NEED_BUILD=0
if [ -f "persistent_warehouse.gcda" ] || [ -f "persistent_requester.gcda" ]; then
    echo -e "${GREEN}Coverage data exists - preserving ALL data, no rebuild${NC}"
    NEED_BUILD=0
elif [ ! -f "persistent_warehouse" ] || [ ! -f "persistent_requester" ]; then
    NEED_BUILD=1
fi

if [ $NEED_BUILD -eq 1 ]; then
    echo -e "${YELLOW}Building binaries (first time only)...${NC}"
    if ! make persistent_warehouse persistent_requester >/dev/null 2>&1; then
        echo -e "${RED}Build failed!${NC}"
        echo "Make sure your Makefile has: CFLAGS += -fprofile-arcs -ftest-coverage"
        exit 1
    fi
    echo -e "${GREEN}Build successful${NC}"
else
    echo -e "${GREEN}Binaries up to date, preserving coverage data${NC}"
fi

echo ""

# Show current coverage before running tests
if [ -f "persistent_warehouse.c.gcov" ] || [ -f "persistent_requester.c.gcov" ]; then
    echo -e "${CYAN}Previous coverage data found - will accumulate${NC}"
    gcov *.c >/dev/null 2>&1
    
    if [ -f "persistent_warehouse.c.gcov" ]; then
        OLD_SERVER=$(gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed" | head -1)
        echo "Previous server: $OLD_SERVER"
    fi
    
    if [ -f "persistent_requester.c.gcov" ]; then
        OLD_CLIENT=$(gcov persistent_requester.c 2>/dev/null | grep "Lines executed" | head -1)
        echo "Previous client: $OLD_CLIENT"
    fi
    echo ""
fi

# Run server coverage
echo -e "${CYAN}Phase 1: Running Enhanced Server Coverage${NC}"
./q6_server_coverage.sh
echo ""

# Run client coverage  
echo -e "${CYAN}Phase 2: Running Enhanced Client Coverage${NC}"
./q6_client_coverage.sh
echo ""

# Generate final report
echo -e "${CYAN}Phase 3: Generating Comprehensive Report${NC}"

# Re-run gcov for fresh accumulated data
gcov *.c >/dev/null 2>&1

# Get coverage data
SERVER_PERCENT=0
CLIENT_PERCENT=0

if [ -f "persistent_warehouse.c.gcov" ]; then
    SERVER_LINE=$(gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed" | head -1)
    SERVER_PERCENT=$(echo "$SERVER_LINE" | grep -o '[0-9]*\.[0-9]*' | head -1)
    SERVER_UNCOVERED=$(grep -c "#####:" persistent_warehouse.c.gcov || echo "0")
fi

if [ -f "persistent_requester.c.gcov" ]; then
    CLIENT_LINE=$(gcov persistent_requester.c 2>/dev/null | grep "Lines executed" | head -1)
    CLIENT_PERCENT=$(echo "$CLIENT_LINE" | grep -o '[0-9]*\.[0-9]*' | head -1)
    CLIENT_UNCOVERED=$(grep -c "#####:" persistent_requester.c.gcov || echo "0")
fi

# Calculate average
if [ "$SERVER_PERCENT" != "0" ] && [ "$CLIENT_PERCENT" != "0" ]; then
    AVG=$(awk "BEGIN {printf \"%.2f\", ($SERVER_PERCENT + $CLIENT_PERCENT) / 2}")
else
    AVG=0
fi

# Display results
echo ""
echo -e "${BLUE}📊 ACCUMULATIVE RESULTS${NC}"
echo "======================="

if [ -f "persistent_warehouse.c.gcov" ]; then
    echo -e "Server: ${GREEN}${SERVER_PERCENT}%${NC} coverage (${SERVER_UNCOVERED} uncovered lines)"
fi

if [ -f "persistent_requester.c.gcov" ]; then
    echo -e "Client: ${GREEN}${CLIENT_PERCENT}%${NC} coverage (${CLIENT_UNCOVERED} uncovered lines)"
fi

echo -e "Average: ${YELLOW}${AVG}%${NC}"

# Check if we reached target
echo ""
if (( $(awk "BEGIN {print ($AVG >= 75)}") )); then
    echo -e "${GREEN}🎉 SUCCESS! You achieved ${AVG}% coverage (≥75%)${NC}"
    echo -e "${GREEN}Enhanced test suite successfully improved coverage!${NC}"
    exit 0
else
    echo -e "${YELLOW}Current coverage: ${AVG}%${NC}"
    echo -e "${YELLOW}Need $(awk "BEGIN {printf \"%.1f\", 75 - $AVG}")% more to reach 75%${NC}"
    
    echo ""
    echo -e "${CYAN}Coverage is accumulating with each run!${NC}"
    echo "Run again to test more edge cases and improve coverage further."
    echo ""
    echo "To analyze remaining gaps:"
    echo "  grep -n '#####:' *.gcov | head -20"
    exit 1
fi