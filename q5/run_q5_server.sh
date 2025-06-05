#!/bin/bash

# run_q5_server.sh - הפעלת שרת Q5 עם UDS ו-Network

echo "🔌 Q5 UDS Warehouse Server"
echo "=========================="

# צבעים
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# נקה socket files ישנים
cleanup_sockets() {
    rm -f /tmp/stream*.sock /tmp/datagram*.sock /tmp/test_*.sock 2>/dev/null
}

show_server_menu() {
    echo -e "\n${BLUE}Choose server configuration:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}NETWORK MODE (TCP/UDP):${NC}"
    echo "  1. Basic network server (TCP:30001, UDP:30002)"
    echo "  2. Network with initial atoms (TCP:30003, UDP:30004)"
    echo "  3. Network with timeout (TCP:30005, UDP:30006)"
    echo ""
    echo -e "${CYAN}UDS MODE (Unix Domain Sockets):${NC}"
    echo "  4. Basic UDS server (stream:/tmp/stream.sock, datagram:/tmp/datagram.sock)"
    echo "  5. UDS with initial atoms (/tmp/stream_atoms.sock, /tmp/datagram_atoms.sock)"
    echo "  6. UDS with timeout (/tmp/stream_timeout.sock, /tmp/datagram_timeout.sock)"
    echo ""
    echo -e "${CYAN}MIXED MODE:${NC}"
    echo "  7. Network TCP + UDS datagram"
    echo "  8. UDS stream + Network UDP"
    echo ""
    echo -e "${CYAN}OTHER:${NC}"
    echo "  9. Custom configuration"
    echo " 10. Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Choice: "
}

run_server() {
    local cmd="$1"
    local desc="$2"
    local connection_info="$3"
    
    echo -e "\n${GREEN}Starting: $desc${NC}"
    echo -e "${YELLOW}Command: $cmd${NC}"
    echo -e "${BLUE}$connection_info${NC}"
    echo ""
    echo -e "${CYAN}⌨️  Server commands you can type:${NC}"
    echo "   GEN SOFT DRINK    - Calculate soft drinks possible"
    echo "   GEN VODKA         - Calculate vodka possible"  
    echo "   GEN CHAMPAGNE     - Calculate champagne possible"
    echo "   shutdown          - Graceful server shutdown"
    echo ""
    echo -e "${RED}Press Ctrl+C to force stop server${NC}"
    echo "════════════════════════════════════════════════"
    
    # נקה socket files לפני הפעלה
    cleanup_sockets
    
    # הפעל שרת
    eval "$cmd"
}

# בדוק שהקבצים קיימים
if [ ! -f "./uds_warehouse" ]; then
    echo -e "${RED}❌ uds_warehouse not found! Run 'make' first.${NC}"
    exit 1
fi

# לולאה ראשית
while true; do
    show_server_menu
    read choice
    
    case $choice in
        1)
            run_server "./uds_warehouse -T 30001 -U 30002" \
                      "Basic Network Server" \
                      "Client connection: ./uds_requester -h localhost -p 30001 -u 30002"
            ;;
        2)
            run_server "./uds_warehouse -T 30003 -U 30004 -c 1000 -o 2000 -H 3000" \
                      "Network Server with Initial Atoms" \
                      "Client connection: ./uds_requester -h localhost -p 30003 -u 30004"
            ;;
        3)
            run_server "./uds_warehouse -T 30005 -U 30006 -t 30" \
                      "Network Server with 30s Timeout" \
                      "Client connection: ./uds_requester -h localhost -p 30005 -u 30006"
            ;;
        4)
            run_server "./uds_warehouse -s /tmp/stream.sock -d /tmp/datagram.sock" \
                      "Basic UDS Server" \
                      "Client connection: ./uds_requester -f /tmp/stream.sock -d /tmp/datagram.sock"
            ;;
        5)
            run_server "./uds_warehouse -s /tmp/stream_atoms.sock -d /tmp/datagram_atoms.sock -c 1000 -o 2000 -H 3000" \
                      "UDS Server with Initial Atoms" \
                      "Client connection: ./uds_requester -f /tmp/stream_atoms.sock -d /tmp/datagram_atoms.sock"
            ;;
        6)
            run_server "./uds_warehouse -s /tmp/stream_timeout.sock -d /tmp/datagram_timeout.sock -t 30" \
                      "UDS Server with 30s Timeout" \
                      "Client connection: ./uds_requester -f /tmp/stream_timeout.sock -d /tmp/datagram_timeout.sock"
            ;;
        7)
            run_server "./uds_warehouse -T 30007 -d /tmp/datagram_mixed1.sock" \
                      "Mixed: Network TCP + UDS Datagram" \
                      "Client connection: ./uds_requester -h localhost -p 30007 -d /tmp/datagram_mixed1.sock"
            ;;
        8)
            run_server "./uds_warehouse -s /tmp/stream_mixed2.sock -U 30008" \
                      "Mixed: UDS Stream + Network UDP" \
                      "Client connection: ./uds_requester -f /tmp/stream_mixed2.sock -u 30008"
            ;;
        9)
            echo -e "\n${YELLOW}Custom Configuration${NC}"
            echo "Available options:"
            echo "  -T <port>     TCP port"
            echo "  -U <port>     UDP port" 
            echo "  -s <path>     UDS stream socket path"
            echo "  -d <path>     UDS datagram socket path"
            echo "  -c <num>      Initial carbon atoms"
            echo "  -o <num>      Initial oxygen atoms"
            echo "  -H <num>      Initial hydrogen atoms"
            echo "  -t <sec>      Timeout seconds"
            echo ""
            echo -n "Enter server arguments: "
            read server_args
            
            if [ -n "$server_args" ]; then
                run_server "./uds_warehouse $server_args" \
                          "Custom Server" \
                          "Use appropriate client options based on server configuration"
            fi
            ;;
        10)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            cleanup_sockets
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read
    cleanup_sockets
done