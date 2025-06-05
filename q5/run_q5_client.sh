#!/bin/bash

# run_q5_client.sh - הפעלת לקוח Q5 עם UDS ו-Network

echo "💻 Q5 UDS Requester Client"
echo "=========================="

# צבעים
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# רשימת שרתים מוגדרים מראש (תואמים לסקריפט השרת)
declare -A NETWORK_SERVERS=(
    ["1"]="localhost 30001 30002 Basic Network Server"
    ["2"]="localhost 30003 30004 Network Server with Initial Atoms"
    ["3"]="localhost 30005 30006 Network Server with 30s Timeout"
)

declare -A UDS_SERVERS=(
    ["4"]="/tmp/stream.sock /tmp/datagram.sock Basic UDS Server"
    ["5"]="/tmp/stream_atoms.sock /tmp/datagram_atoms.sock UDS Server with Initial Atoms"
    ["6"]="/tmp/stream_timeout.sock /tmp/datagram_timeout.sock UDS Server with 30s Timeout"
)

show_client_menu() {
    echo -e "\n${BLUE}Choose client configuration:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}NETWORK MODE:${NC}"
    echo "  1. Connect to Basic Network Server (localhost:30001/30002)"
    echo "  2. Connect to Network Server with Initial Atoms (localhost:30003/30004)"
    echo "  3. Connect to Network Server with Timeout (localhost:30005/30006)"
    echo ""
    echo -e "${CYAN}UDS MODE:${NC}"
    echo "  4. Connect to Basic UDS Server (/tmp/stream.sock, /tmp/datagram.sock)"
    echo "  5. Connect to UDS Server with Atoms (/tmp/stream_atoms.sock, /tmp/datagram_atoms.sock)"
    echo "  6. Connect to UDS Server with Timeout (/tmp/stream_timeout.sock, /tmp/datagram_timeout.sock)"
    echo ""
    echo -e "${CYAN}TESTING:${NC}"
    echo "  7. Auto-test with network server"
    echo "  8. Auto-test with UDS server"
    echo "  9. Stress test (multiple clients)"
    echo ""
    echo -e "${CYAN}OTHER:${NC}"
    echo " 10. Custom connection"
    echo " 11. Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Choice: "
}

run_network_client() {
    local host="$1"
    local tcp_port="$2"
    local udp_port="$3"
    local desc="$4"
    
    echo -e "\n${GREEN}Connecting to: $desc${NC}"
    echo -e "${BLUE}Network: $host:$tcp_port (TCP), $host:$udp_port (UDP)${NC}"
    echo ""
    echo -e "${CYAN}🎮 Usage instructions:${NC}"
    echo "   1. Add atoms        - Add CARBON/OXYGEN/HYDROGEN via TCP"
    echo "   2. Request molecules - Request WATER/ALCOHOL/etc via UDP"
    echo "   3. Quit            - Exit client"
    echo ""
    echo -e "${RED}Press Ctrl+C to disconnect${NC}"
    echo "══════════════════════════════════════════════"
    
    # בדוק חיבור לשרת
    if ! nc -z "$host" "$tcp_port" 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to server at $host:$tcp_port${NC}"
        echo -e "${YELLOW}💡 Make sure server is running first!${NC}"
        return 1
    fi
    
    ./uds_requester -h "$host" -p "$tcp_port" -u "$udp_port"
}

run_uds_client() {
    local stream_path="$1"
    local datagram_path="$2"
    local desc="$3"
    
    echo -e "\n${GREEN}Connecting to: $desc${NC}"
    echo -e "${BLUE}UDS Stream: $stream_path${NC}"
    echo -e "${BLUE}UDS Datagram: $datagram_path${NC}"
    echo ""
    echo -e "${CYAN}🎮 Usage instructions:${NC}"
    echo "   1. Add atoms        - Add CARBON/OXYGEN/HYDROGEN via UDS stream"
    echo "   2. Request molecules - Request WATER/ALCOHOL/etc via UDS datagram"
    echo "   3. Quit            - Exit client"
    echo ""
    echo -e "${RED}Press Ctrl+C to disconnect${NC}"
    echo "══════════════════════════════════════════════"
    
    # בדוק שקבצי socket קיימים
    if [ ! -S "$stream_path" ]; then
        echo -e "${RED}❌ UDS stream socket not found: $stream_path${NC}"
        echo -e "${YELLOW}💡 Make sure server is running first!${NC}"
        return 1
    fi
    
    ./uds_requester -f "$stream_path" -d "$datagram_path"
}

auto_test_network() {
    local host="$1"
    local tcp_port="$2"
    local udp_port="$3"
    local desc="$4"
    
    echo -e "\n${GREEN}Auto-testing network client with: $desc${NC}"
    echo -e "${YELLOW}Running predefined commands...${NC}"
    
    if ! nc -z "$host" "$tcp_port" 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to server at $host:$tcp_port${NC}"
        return 1
    fi
    
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "500"    # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "2"      # Oxygen
        echo "1000"   # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "3"      # Hydrogen
        echo "1500"   # Amount
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "1"      # Water
        echo "10"     # Quantity
        sleep 1
        echo "2"      # Request molecules
        echo "3"      # Alcohol
        echo "5"      # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 30s ./uds_requester -h "$host" -p "$tcp_port" -u "$udp_port"
    
    echo -e "${GREEN}✅ Network auto-test completed!${NC}"
}

auto_test_uds() {
    local stream_path="$1"
    local datagram_path="$2"
    local desc="$3"
    
    echo -e "\n${GREEN}Auto-testing UDS client with: $desc${NC}"
    echo -e "${YELLOW}Running predefined commands...${NC}"
    
    if [ ! -S "$stream_path" ]; then
        echo -e "${RED}❌ UDS stream socket not found: $stream_path${NC}"
        return 1
    fi
    
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "300"    # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "2"      # Oxygen
        echo "600"    # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "3"      # Hydrogen
        echo "900"    # Amount
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "1"      # Water
        echo "15"     # Quantity
        sleep 1
        echo "2"      # Request molecules
        echo "2"      # Carbon dioxide
        echo "8"      # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 30s ./uds_requester -f "$stream_path" -d "$datagram_path"
    
    echo -e "${GREEN}✅ UDS auto-test completed!${NC}"
}

stress_test() {
    echo -e "\n${GREEN}Stress Test - Multiple Clients${NC}"
    echo "Choose server type for stress test:"
    echo "1. Network server (30001/30002)"
    echo "2. UDS server (/tmp/stream.sock, /tmp/datagram.sock)"
    echo -n "Choice: "
    read stress_choice
    
    case $stress_choice in
        1)
            if ! nc -z localhost 30001 2>/dev/null; then
                echo -e "${RED}❌ Network server not running${NC}"
                return 1
            fi
            
            echo -e "${YELLOW}Starting 3 network clients...${NC}"
            for i in {1..3}; do
                {
                    echo -e "${BLUE}Network Client $i starting...${NC}"
                    {
                        echo "1"; echo "1"; echo "$((100 * i))"; sleep 2; echo "4"
                        echo "2"; echo "1"; echo "$i"; sleep 2; echo "5"; echo "3"
                    } | timeout 20s ./uds_requester -h localhost -p 30001 -u 30002 > network_client_$i.log 2>&1
                    echo -e "${GREEN}Network Client $i completed${NC}"
                } &
            done
            wait
            ;;
        2)
            if [ ! -S "/tmp/stream.sock" ]; then
                echo -e "${RED}❌ UDS server not running${NC}"
                return 1
            fi
            
            echo -e "${YELLOW}Starting 3 UDS clients...${NC}"
            for i in {1..3}; do
                {
                    echo -e "${BLUE}UDS Client $i starting...${NC}"
                    {
                        echo "1"; echo "1"; echo "$((50 * i))"; sleep 2; echo "4"
                        echo "2"; echo "1"; echo "$i"; sleep 2; echo "5"; echo "3"
                    } | timeout 20s ./uds_requester -f /tmp/stream.sock -d /tmp/datagram.sock > uds_client_$i.log 2>&1
                    echo -e "${GREEN}UDS Client $i completed${NC}"
                } &
            done
            wait
            ;;
    esac
    
    echo -e "${GREEN}✅ Stress test completed!${NC}"
}

# בדוק שהקבצים קיימים
if [ ! -f "./uds_requester" ]; then
    echo -e "${RED}❌ uds_requester not found! Run 'make' first.${NC}"
    exit 1
fi

# לולאה ראשית
while true; do
    show_client_menu
    read choice
    
    case $choice in
        1|2|3)
            server_info="${NETWORK_SERVERS[$choice]}"
            IFS=' ' read -r host tcp_port udp_port desc <<< "$server_info"
            run_network_client "$host" "$tcp_port" "$udp_port" "$desc"
            ;;
        4|5|6)
            server_info="${UDS_SERVERS[$choice]}"
            IFS=' ' read -r stream_path datagram_path desc <<< "$server_info"
            run_uds_client "$stream_path" "$datagram_path" "$desc"
            ;;
        7)
            echo -e "\n${BLUE}Choose network server for auto-test:${NC}"
            echo "1. Basic (30001/30002)"
            echo "2. With Atoms (30003/30004)"
            echo "3. With Timeout (30005/30006)"
            echo -n "Choice: "
            read auto_choice
            
            if [[ "$auto_choice" =~ ^[1-3]$ ]]; then
                server_info="${NETWORK_SERVERS[$auto_choice]}"
                IFS=' ' read -r host tcp_port udp_port desc <<< "$server_info"
                auto_test_network "$host" "$tcp_port" "$udp_port" "$desc"
            fi
            ;;
        8)
            echo -e "\n${BLUE}Choose UDS server for auto-test:${NC}"
            echo "1. Basic (/tmp/stream.sock)"
            echo "2. With Atoms (/tmp/stream_atoms.sock)"
            echo "3. With Timeout (/tmp/stream_timeout.sock)"
            echo -n "Choice: "
            read auto_choice
            
            case $auto_choice in
                1) auto_test_uds "/tmp/stream.sock" "/tmp/datagram.sock" "Basic UDS" ;;
                2) auto_test_uds "/tmp/stream_atoms.sock" "/tmp/datagram_atoms.sock" "UDS with Atoms" ;;
                3) auto_test_uds "/tmp/stream_timeout.sock" "/tmp/datagram_timeout.sock" "UDS with Timeout" ;;
            esac
            ;;
        9)
            stress_test
            ;;
        10)
            echo -e "\n${YELLOW}Custom Connection${NC}"
            echo "Choose connection type:"
            echo "1. Network (TCP/UDP)"
            echo "2. UDS (Stream/Datagram)"
            echo -n "Choice: "
            read conn_type
            
            case $conn_type in
                1)
                    echo -n "Enter hostname/IP: "
                    read host
                    echo -n "Enter TCP port: "
                    read tcp_port
                    echo -n "Enter UDP port (or press enter to skip): "
                    read udp_port
                    
                    if [ -z "$udp_port" ]; then
                        ./uds_requester -h "$host" -p "$tcp_port"
                    else
                        ./uds_requester -h "$host" -p "$tcp_port" -u "$udp_port"
                    fi
                    ;;
                2)
                    echo -n "Enter UDS stream path: "
                    read stream_path
                    echo -n "Enter UDS datagram path (or press enter to skip): "
                    read datagram_path
                    
                    if [ -z "$datagram_path" ]; then
                        ./uds_requester -f "$stream_path"
                    else
                        ./uds_requester -f "$stream_path" -d "$datagram_path"
                    fi
                    ;;
            esac
            ;;
        11)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read
done