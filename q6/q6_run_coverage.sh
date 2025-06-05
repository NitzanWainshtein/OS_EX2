#!/bin/bash

# q6_run_coverage.sh - Simple Master Runner (FIXED)
# No fancy progress bars, just reliable execution

echo "🎯 Q6 COVERAGE RUNNER"
echo "===================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

# Clean and build
echo -e "${BLUE}Cleaning and building...${NC}"
make clean >/dev/null 2>&1
rm -f *.gcov *.gcno *.gcda coverage_report_q6.txt 2>/dev/null
pkill -f persistent_warehouse 2>/dev/null
pkill -f persistent_requester 2>/dev/null
sleep 1

if ! make all >/dev/null 2>&1; then
    echo -e "${RED}Build failed!${NC}"
    echo "Make sure your Makefile has: CFLAGS += -fprofile-arcs -ftest-coverage"
    exit 1
fi

echo -e "${GREEN}Build successful${NC}"
echo ""

# Run server coverage
echo -e "${BLUE}Phase 1: Running Server Coverage${NC}"
./q6_server_coverage.sh
echo ""

# Run client coverage
echo -e "${BLUE}Phase 2: Running Client Coverage${NC}"
./q6_client_coverage.sh
echo ""

# Generate final report
echo -e "${BLUE}Phase 3: Generating Final Report${NC}"

# Re-run gcov for fresh data
gcov *.c >/dev/null 2>&1

# Create report
echo "=== Q6 COVERAGE REPORT ===" > coverage_report_q6.txt
echo "Generated: $(date)" >> coverage_report_q6.txt
echo "" >> coverage_report_q6.txt

# Get coverage data
SERVER_PERCENT=0
CLIENT_PERCENT=0

if [ -f "persistent_warehouse.c.gcov" ]; then
    SERVER_LINE=$(gcov persistent_warehouse.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "SERVER: $SERVER_LINE" >> coverage_report_q6.txt
    SERVER_PERCENT=$(echo "$SERVER_LINE" | grep -o '[0-9]*\.[0-9]*' | head -1)
    
    SERVER_UNCOVERED=$(grep -c "#####:" persistent_warehouse.c.gcov || echo "0")
    echo "  Uncovered lines: $SERVER_UNCOVERED" >> coverage_report_q6.txt
fi

if [ -f "persistent_requester.c.gcov" ]; then
    CLIENT_LINE=$(gcov persistent_requester.c 2>/dev/null | grep "Lines executed" | head -1)
    echo "CLIENT: $CLIENT_LINE" >> coverage_report_q6.txt
    CLIENT_PERCENT=$(echo "$CLIENT_LINE" | grep -o '[0-9]*\.[0-9]*' | head -1)
    
    CLIENT_UNCOVERED=$(grep -c "#####:" persistent_requester.c.gcov || echo "0")
    echo "  Uncovered lines: $CLIENT_UNCOVERED" >> coverage_report_q6.txt
fi

# Calculate average
if [ "$SERVER_PERCENT" != "0" ] && [ "$CLIENT_PERCENT" != "0" ]; then
    AVG=$(awk "BEGIN {printf \"%.2f\", ($SERVER_PERCENT + $CLIENT_PERCENT) / 2}")
else
    AVG=0
fi

echo "" >> coverage_report_q6.txt
echo "AVERAGE: ${AVG}%" >> coverage_report_q6.txt

# Display results
echo ""
echo -e "${BLUE}📊 RESULTS${NC}"
echo "=========="

if [ -f "persistent_warehouse.c.gcov" ]; then
    echo -e "Server: ${GREEN}${SERVER_PERCENT}%${NC} coverage"
fi

if [ -f "persistent_requester.c.gcov" ]; then
    echo -e "Client: ${GREEN}${CLIENT_PERCENT}%${NC} coverage"
fi

echo -e "Average: ${YELLOW}${AVG}%${NC}"

# Check if we reached 75%
echo ""
if (( $(awk "BEGIN {print ($AVG >= 75)}") )); then
    echo -e "${GREEN}🎉 SUCCESS! You achieved ${AVG}% coverage (≥75%)${NC}"
    exit 0
else
    echo -e "${YELLOW}Current coverage: ${AVG}%${NC}"
    echo -e "${YELLOW}Need $(awk "BEGIN {printf \"%.1f\", 75 - $AVG}")% more to reach 75%${NC}"
    
    echo ""
    echo "Tips to improve:"
    echo "• Run manual interactive sessions"
    echo "• Test error scenarios"
    echo "• Test all admin commands"
    echo "• Check .gcov files for uncovered lines:"
    echo "  grep -n '#####:' *.gcov | head -20"
    exit 1
fi