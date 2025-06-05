#!/bin/bash

# run_q6_client.sh - הפעלת לקוח Q6 עם Persistent Warehouse

echo "💻 Q6 Persistent Requester Client"
echo "================================="

# צבעים
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# רשימת שרתים מוגדרים מראש (תואמים לסקריפט השרת)
declare -A NETWORK_SERVERS=(
    ["1"]="localhost 40001 40002 Basic Network Server with Persistence"
    ["2"]="localhost 40003 40004 Network Server with Initial Atoms + Persistence"
    ["3"]="localhost 40005 40006 Network Server with 30s Timeout + Persistence"
)

declare -A UDS_SERVERS=(
    ["4"]="/tmp/stream.sock /tmp/datagram.sock Basic UDS Server with Persistence"
    ["5"]="/tmp/stream_atoms.sock /tmp/datagram_atoms.sock UDS Server with Initial Atoms + Persistence"
    ["6"]="/tmp/stream_timeout.sock /tmp/datagram_timeout.sock UDS Server with 30s Timeout + Persistence"
)

declare -A MIXED_SERVERS=(
    ["7"]="TCP localhost 40007 /tmp/datagram_mixed1.sock Mixed: Network TCP + UDS Datagram + Persistence"
    ["8"]="UDS /tmp/stream_mixed2.sock 40008 Mixed: UDS Stream + Network UDP + Persistence"
)

show_client_menu() {
    echo -e "\n${BLUE}Choose Q6 client configuration:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}NETWORK MODE + PERSISTENCE:${NC}"
    echo "  1. Connect to Basic Network Server (localhost:40001/40002)"
    echo "  2. Connect to Network Server with Initial Atoms (localhost:40003/40004)"
    echo "  3. Connect to Network Server with Timeout (localhost:40005/40006)"
    echo ""
    echo -e "${CYAN}UDS MODE + PERSISTENCE:${NC}"
    echo "  4. Connect to Basic UDS Server (/tmp/stream.sock, /tmp/datagram.sock)"
    echo "  5. Connect to UDS Server with Atoms (/tmp/stream_atoms.sock, /tmp/datagram_atoms.sock)"
    echo "  6. Connect to UDS Server with Timeout (/tmp/stream_timeout.sock, /tmp/datagram_timeout.sock)"
    echo ""
    echo -e "${CYAN}MIXED MODE + PERSISTENCE:${NC}"
    echo "  7. Connect to Mixed TCP + UDS Datagram (localhost:40007, /tmp/datagram_mixed1.sock)"
    echo "  8. Connect to Mixed UDS Stream + UDP (/tmp/stream_mixed2.sock, localhost:40008)"
    echo ""
    echo -e "${CYAN}TESTING & DEMO:${NC}"
    echo "  9. Auto-test with network server + persistence"
    echo " 10. Auto-test with UDS server + persistence"
    echo " 11. Stress test (multiple clients) + persistence"
    echo " 12. Demo persistence (connect, add, quit, reconnect)"
    echo ""
    echo -e "${CYAN}OTHER:${NC}"
    echo " 13. Custom connection"
    echo " 14. Exit"
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
    echo -e "${CYAN}Persistent Storage: Inventory saved automatically${NC}"
    echo ""
    echo -e "${CYAN}🎮 Usage instructions:${NC}"
    echo "   1. Add atoms        - Add CARBON/OXYGEN/HYDROGEN via TCP"
    echo "   2. Request molecules - Request WATER/ALCOHOL/etc via UDP"
    echo "   3. Quit            - Exit client (inventory remains saved)"
    echo ""
    echo -e "${YELLOW}💾 Persistence Features:${NC}"
    echo "   • All changes are automatically saved to disk"
    echo "   • Reconnect anytime to see your saved inventory"
    echo "   • Multiple clients can connect simultaneously"
    echo "   • Server restart preserves all your data"
    echo ""
    echo -e "${RED}Press Ctrl+C to disconnect${NC}"
    echo "══════════════════════════════════════════════"
    
    # בדוק חיבור לשרת
    if ! nc -z "$host" "$tcp_port" 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to server at $host:$tcp_port${NC}"
        echo -e "${YELLOW}💡 Make sure server is running first!${NC}"
        return 1
    fi
    
    ./persistent_requester -h "$host" -p "$tcp_port" -u "$udp_port"
}

run_uds_client() {
    local stream_path="$1"
    local datagram_path="$2"
    local desc="$3"
    
    echo -e "\n${GREEN}Connecting to: $desc${NC}"
    echo -e "${BLUE}UDS Stream: $stream_path${NC}"
    echo -e "${BLUE}UDS Datagram: $datagram_path${NC}"
    echo -e "${CYAN}Persistent Storage: Inventory saved automatically${NC}"
    echo ""
    echo -e "${CYAN}🎮 Usage instructions:${NC}"
    echo "   1. Add atoms        - Add CARBON/OXYGEN/HYDROGEN via UDS stream"
    echo "   2. Request molecules - Request WATER/ALCOHOL/etc via UDS datagram"
    echo "   3. Quit            - Exit client (inventory remains saved)"
    echo ""
    echo -e "${YELLOW}💾 Persistence Features:${NC}"
    echo "   • All changes are automatically saved to disk"
    echo "   • Memory-mapped files for efficient access"
    echo "   • File locking prevents data corruption"
    echo "   • Inventory persists across server restarts"
    echo ""
    echo -e "${RED}Press Ctrl+C to disconnect${NC}"
    echo "══════════════════════════════════════════════"
    
    # בדוק שקבצי socket קיימים
    if [ ! -S "$stream_path" ]; then
        echo -e "${RED}❌ UDS stream socket not found: $stream_path${NC}"
        echo -e "${YELLOW}💡 Make sure server is running first!${NC}"
        return 1
    fi
    
    ./persistent_requester -f "$stream_path" -d "$datagram_path"
}

run_mixed_client() {
    local mode="$1"
    local param1="$2"
    local param2="$3"
    local desc="$4"
    
    echo -e "\n${GREEN}Connecting to: $desc${NC}"
    echo -e "${CYAN}Persistent Storage: Inventory saved automatically${NC}"
    echo ""
    
    if [ "$mode" = "TCP" ]; then
        # TCP + UDS Datagram
        echo -e "${BLUE}TCP: $param1:$param2, UDS Datagram: $param2${NC}"
        echo -e "${RED}Press Ctrl+C to disconnect${NC}"
        echo "══════════════════════════════════════════════"
        
        if ! nc -z "$param1" "$param2" 2>/dev/null; then
            echo -e "${RED}❌ Cannot connect to TCP server${NC}"
            return 1
        fi
        
        ./persistent_requester -h "$param1" -p "$param2" -d "$3"
    else
        # UDS Stream + UDP
        echo -e "${BLUE}UDS Stream: $param1, UDP: localhost:$param2${NC}"
        echo -e "${RED}Press Ctrl+C to disconnect${NC}"
        echo "══════════════════════════════════════════════"
        
        if [ ! -S "$param1" ]; then
            echo -e "${RED}❌ UDS stream socket not found${NC}"
            return 1
        fi
        
        ./persistent_requester -f "$param1" -u "$param2"
    fi
}

auto_test_network() {
    local host="$1"
    local tcp_port="$2"
    local udp_port="$3"
    local desc="$4"
    
    echo -e "\n${GREEN}Auto-testing network client with persistence: $desc${NC}"
    echo -e "${YELLOW}Running predefined commands to test persistence...${NC}"
    
    if ! nc -z "$host" "$tcp_port" 2>/dev/null; then
        echo -e "${RED}❌ Cannot connect to server at $host:$tcp_port${NC}"
        return 1
    fi
    
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "1500"   # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "2"      # Oxygen
        echo "2500"   # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "3"      # Hydrogen
        echo "3500"   # Amount
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "1"      # Water
        echo "100"    # Quantity
        sleep 1
        echo "2"      # Request molecules
        echo "3"      # Alcohol
        echo "50"     # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 45s ./persistent_requester -h "$host" -p "$tcp_port" -u "$udp_port"
    
    echo -e "${GREEN}✅ Network auto-test with persistence completed!${NC}"
    echo -e "${CYAN}💾 All changes have been saved to the inventory file${NC}"
}

auto_test_uds() {
    local stream_path="$1"
    local datagram_path="$2"
    local desc="$3"
    
    echo -e "\n${GREEN}Auto-testing UDS client with persistence: $desc${NC}"
    echo -e "${YELLOW}Running predefined commands to test persistence...${NC}"
    
    if [ ! -S "$stream_path" ]; then
        echo -e "${RED}❌ UDS stream socket not found: $stream_path${NC}"
        return 1
    fi
    
    {
        echo "1"      # Add atoms
        echo "1"      # Carbon
        echo "800"    # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "2"      # Oxygen
        echo "1200"   # Amount
        sleep 1
        echo "4"      # Back
        echo "1"      # Add atoms
        echo "3"      # Hydrogen
        echo "1800"   # Amount
        sleep 1
        echo "4"      # Back
        echo "2"      # Request molecules
        echo "1"      # Water
        echo "75"     # Quantity
        sleep 1
        echo "2"      # Request molecules
        echo "2"      # Carbon dioxide
        echo "25"     # Quantity
        sleep 1
        echo "5"      # Back
        echo "3"      # Quit
    } | timeout 45s ./persistent_requester -f "$stream_path" -d "$datagram_path"
    
    echo -e "${GREEN}✅ UDS auto-test with persistence completed!${NC}"
    echo -e "${CYAN}💾 All changes have been saved to the inventory file${NC}"
}

demo_persistence() {
    echo -e "\n${GREEN}Persistence Demo${NC}"
    echo "================"
    echo "This demo will:"
    echo "1. Connect to server and add some atoms"
    echo "2. Quit the client"
    echo "3. Reconnect to show inventory was saved"
    echo ""
    echo "Choose server type for demo:"
    echo "1. Network server (40001/40002)"
    echo "2. UDS server (/tmp/stream.sock, /tmp/datagram.sock)"
    echo -n "Choice: "
    read demo_choice
    
    case $demo_choice in
        1)
            if ! nc -z localhost 40001 2>/dev/null; then
                echo -e "${RED}❌ Network server not running on 40001${NC}"
                return 1
            fi
            
            echo -e "\n${BLUE}Phase 1: Adding atoms and quitting...${NC}"
            {
                echo "1"; echo "1"; echo "2000"; sleep 2; echo "4"
                echo "1"; echo "2"; echo "3000"; sleep 2; echo "4"
                echo "3"
            } | timeout 20s ./persistent_requester -h localhost -p 40001 -u 40002
            
            echo -e "\n${YELLOW}Pausing for 3 seconds...${NC}"
            sleep 3
            
            echo -e "\n${BLUE}Phase 2: Reconnecting to check persistence...${NC}"
            echo -e "${CYAN}The inventory should show the atoms we added in Phase 1!${NC}"
            {
                echo "1"; echo "1"; echo "500"; sleep 2; echo "4"; echo "3"
            } | timeout 15s ./persistent_requester -h localhost -p 40001 -u 40002
            ;;
        2)
            if [ ! -S "/tmp/stream.sock" ]; then
                echo -e "${RED}❌ UDS server not running${NC}"
                return 1
            fi
            
            echo -e "\n${BLUE}Phase 1: Adding atoms and quitting...${NC}"
            {
                echo "1"; echo "1"; echo "1500"; sleep 2; echo "4"
                echo "1"; echo "3"; echo "2500"; sleep 2; echo "4"
                echo "3"
            } | timeout 20s ./persistent_requester -f /tmp/stream.sock -d /tmp/datagram.sock
            
            echo -e "\n${YELLOW}Pausing for 3 seconds...${NC}"
            sleep 3
            
            echo -e "\n${BLUE}Phase 2: Reconnecting to check persistence...${NC}"
            echo -e "${CYAN}The inventory should show the atoms we added in Phase 1!${NC}"
            {
                echo "1"; echo "2"; echo "300"; sleep 2; echo "4"; echo "3"
            } | timeout 15s ./persistent_requester -f /tmp/stream.sock -d /tmp/datagram.sock
            ;;
    esac
    
    echo -e "\n${GREEN}✅ Persistence demo completed!${NC}"
    echo -e "${CYAN}💾 As you can see, inventory persists across connections!${NC}"
}

stress_test() {
    echo -e "\n${GREEN}Stress Test - Multiple Clients with Persistence${NC}"
    echo "Choose server type for stress test:"
    echo "1. Network server (40001/40002)"
    echo "2. UDS server (/tmp/stream.sock, /tmp/datagram.sock)"
    echo -n "Choice: "
    read stress_choice
    
    case $stress_choice in
        1)
            if ! nc -z localhost 40001 2>/dev/null; then
                echo -e "${RED}❌ Network server not running${NC}"
                return 1
            fi
            
            echo -e "${YELLOW}Starting 4 network clients with persistent operations...${NC}"
            for i in {1..4}; do
                {
                    echo -e "${BLUE}Network Client $i starting...${NC}"
                    {
                        echo "1"; echo "1"; echo "$((200 * i))"; sleep 2; echo "4"
                        echo "1"; echo "2"; echo "$((150 * i))"; sleep 2; echo "4"
                        echo "2"; echo "1"; echo "$((5 + i))"; sleep 2; echo "5"; echo "3"
                    } | timeout 25s ./persistent_requester -h localhost -p 40001 -u 40002 > network_client_$i.log 2>&1
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
            
            echo -e "${YELLOW}Starting 4 UDS clients with persistent operations...${NC}"
            for i in {1..4}; do
                {
                    echo -e "${BLUE}UDS Client $i starting...${NC}"
                    {
                        echo "1"; echo "1"; echo "$((100 * i))"; sleep 2; echo "4"
                        echo "1"; echo "3"; echo "$((300 * i))"; sleep 2; echo "4"
                        echo "2"; echo "1"; echo "$((3 + i))"; sleep 2; echo "5"; echo "3"
                    } | timeout 25s ./persistent_requester -f /tmp/stream.sock -d /tmp/datagram.sock > uds_client_$i.log 2>&1
                    echo -e "${GREEN}UDS Client $i completed${NC}"
                } &
            done
            wait
            ;;
    esac
    
    echo -e "${GREEN}✅ Stress test completed!${NC}"
    echo -e "${CYAN}💾 All client operations have been saved to the persistent inventory!${NC}"
}

# בדוק שהקבצים קיימים
if [ ! -f "./persistent_requester" ]; then
    echo -e "${RED}❌ persistent_requester not found! Run 'make' first.${NC}"
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
            server_info="${MIXED_SERVERS[7]}"
            IFS=' ' read -r mode host tcp_port datagram_path desc <<< "$server_info"
            run_mixed_client "$mode" "$host" "$tcp_port" "$datagram_path" "$desc"
            ;;
        8)
            server_info="${MIXED_SERVERS[8]}"
            IFS=' ' read -r mode stream_path udp_port desc <<< "$server_info"
            run_mixed_client "$mode" "$stream_path" "$udp_port" "$desc"
            ;;
        9)
            echo -e "\n${BLUE}Choose network server for auto-test:${NC}"
            echo "1. Basic (40001/40002)"
            echo "2. With Atoms (40003/40004)"
            echo "3. With Timeout (40005/40006)"
            echo -n "Choice: "
            read auto_choice
            
            if [[ "$auto_choice" =~ ^[1-3]$ ]]; then
                server_info="${NETWORK_SERVERS[$auto_choice]}"
                IFS=' ' read -r host tcp_port udp_port desc <<< "$server_info"
                auto_test_network "$host" "$tcp_port" "$udp_port" "$desc"
            fi
            ;;
        10)
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
        11)
            stress_test
            ;;
        12)
            demo_persistence
            ;;
        13)
            echo -e "\n${YELLOW}Custom Connection${NC}"
            echo "Choose connection type:"
            echo "1. Network (TCP/UDP)"
            echo "2. UDS (Stream/Datagram)"
            echo "3. Mixed (TCP + UDS Datagram)"
            echo "4. Mixed (UDS Stream + UDP)"
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
                        ./persistent_requester -h "$host" -p "$tcp_port"
                    else
                        ./persistent_requester -h "$host" -p "$tcp_port" -u "$udp_port"
                    fi
                    ;;
                2)
                    echo -n "Enter UDS stream path: "
                    read stream_path
                    echo -n "Enter UDS datagram path (or press enter to skip): "
                    read datagram_path
                    
                    if [ -z "$datagram_path" ]; then
                        ./persistent_requester -f "$stream_path"
                    else
                        ./persistent_requester -f "$stream_path" -d "$datagram_path"
                    fi
                    ;;
                3)
                    echo -n "Enter hostname/IP: "
                    read host
                    echo -n "Enter TCP port: "
                    read tcp_port
                    echo -n "Enter UDS datagram path: "
                    read datagram_path
                    ./persistent_requester -h "$host" -p "$tcp_port" -d "$datagram_path"
                    ;;
                4)
                    echo -n "Enter UDS stream path: "
                    read stream_path
                    echo -n "Enter UDP port: "
                    read udp_port
                    ./persistent_requester -f "$stream_path" -u "$udp_port"
                    ;;
            esac
            ;;
        14)
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