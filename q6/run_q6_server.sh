#!/bin/bash

# run_q6_server.sh - הפעלת שרת Q6 עם Persistent Storage + UDS + Network

echo "💾 Q6 Persistent Warehouse Server"
echo "================================="

# צבעים
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# נקה socket files ו-inventory files ישנים
cleanup_files() {
    rm -f /tmp/stream*.sock /tmp/datagram*.sock /tmp/test_*.sock 2>/dev/null
    # אל תמחק קבצי inventory אוטומטית - הם חשובים לצורך persistence!
}

show_server_menu() {
    echo -e "\n${BLUE}Choose Q6 server configuration:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}NETWORK MODE (TCP/UDP) + PERSISTENCE:${NC}"
    echo "  1. Basic network server (TCP:40001, UDP:40002) + save file"
    echo "  2. Network with initial atoms + save file (TCP:40003, UDP:40004)"
    echo "  3. Network with timeout + save file (TCP:40005, UDP:40006)"
    echo ""
    echo -e "${CYAN}UDS MODE + PERSISTENCE:${NC}"
    echo "  4. Basic UDS server + save file (stream:/tmp/stream.sock, datagram:/tmp/datagram.sock)"
    echo "  5. UDS with initial atoms + save file (/tmp/stream_atoms.sock, /tmp/datagram_atoms.sock)"
    echo "  6. UDS with timeout + save file (/tmp/stream_timeout.sock, /tmp/datagram_timeout.sock)"
    echo ""
    echo -e "${CYAN}MIXED MODE + PERSISTENCE:${NC}"
    echo "  7. Network TCP + UDS datagram + save file"
    echo "  8. UDS stream + Network UDP + save file"
    echo ""
    echo -e "${CYAN}TESTING & DEMO:${NC}"
    echo "  9. Demo server with large inventory + persistence"
    echo " 10. Multi-process test (use existing inventory file)"
    echo ""
    echo -e "${CYAN}OTHER:${NC}"
    echo " 11. Custom configuration"
    echo " 12. Show existing inventory files"
    echo " 13. Clean all files (inventory + sockets)"
    echo " 14. Exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Choice: "
}

run_server() {
    local cmd="$1"
    local desc="$2"
    local connection_info="$3"
    local save_file="$4"
    
    echo -e "\n${GREEN}Starting: $desc${NC}"
    echo -e "${YELLOW}Command: $cmd${NC}"
    echo -e "${BLUE}$connection_info${NC}"
    if [ -n "$save_file" ]; then
        echo -e "${CYAN}Save file: $save_file${NC}"
        if [ -f "$save_file" ]; then
            echo -e "${GREEN}  ✅ Existing inventory file found - will load existing data${NC}"
        else
            echo -e "${YELLOW}  📁 New inventory file will be created${NC}"
        fi
    fi
    echo ""
    echo -e "${CYAN}⌨️  Server commands you can type:${NC}"
    echo "   GEN SOFT DRINK    - Calculate soft drinks possible"
    echo "   GEN VODKA         - Calculate vodka possible"  
    echo "   GEN CHAMPAGNE     - Calculate champagne possible"
    echo "   shutdown          - Graceful server shutdown (saves inventory)"
    echo ""
    echo -e "${YELLOW}💾 Persistent Storage Features:${NC}"
    echo "   • Inventory automatically saved to disk"
    echo "   • Memory-mapped file for efficient access"
    echo "   • File locking prevents multiple servers on same file"
    echo "   • Inventory persists across server restarts"
    echo ""
    echo -e "${RED}Press Ctrl+C to force stop server${NC}"
    echo "════════════════════════════════════════════════"
    
    # נקה socket files לפני הפעלה (אבל לא inventory files!)
    cleanup_files
    
    # הפעל שרת
    eval "$cmd"
}

show_inventory_files() {
    echo -e "\n${BLUE}📋 Existing Inventory Files${NC}"
    echo "=============================="
    
    local found_files=false
    
    for file in /tmp/*.dat; do
        if [ -f "$file" ]; then
            found_files=true
            local size=$(wc -c < "$file" 2>/dev/null || echo "0")
            local modified=$(stat -c %y "$file" 2>/dev/null || echo "unknown")
            echo -e "${GREEN}📄 $file${NC}"
            echo "   Size: $size bytes"
            echo "   Modified: $modified"
            echo ""
        fi
    done
    
    if ! $found_files; then
        echo -e "${YELLOW}No inventory files found in /tmp/${NC}"
        echo "Inventory files are created when you first run a server with -f option"
    fi
    
    echo -e "\n${CYAN}💡 Tips:${NC}"
    echo "• Use the same -f file path to resume with existing inventory"
    echo "• Different file paths create separate inventories"
    echo "• File locking prevents conflicts between servers"
}

clean_all_files() {
    echo -e "\n${YELLOW}🧹 Cleaning All Files${NC}"
    echo "===================="
    
    echo "This will remove:"
    echo "• All socket files (/tmp/*.sock)"
    echo "• All inventory files (/tmp/*.dat)"
    echo "• Test and log files"
    echo ""
    echo -e "${RED}⚠️  This will DELETE all saved inventory data!${NC}"
    echo -n "Are you sure? (y/N): "
    read confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f /tmp/*.sock /tmp/*.dat 2>/dev/null
        rm -f server_*.log client_*.log test_*.log *.log 2>/dev/null
        pkill -f persistent_warehouse 2>/dev/null || true
        echo -e "${GREEN}✅ All files cleaned${NC}"
    else
        echo -e "${BLUE}Cleanup cancelled${NC}"
    fi
}

# בדוק שהקבצים קיימים
if [ ! -f "./persistent_warehouse" ]; then
    echo -e "${RED}❌ persistent_warehouse not found! Run 'make' first.${NC}"
    exit 1
fi

# לולאה ראשית
while true; do
    show_server_menu
    read choice
    
    case $choice in
        1)
            run_server "./persistent_warehouse -T 40001 -U 40002 -f /tmp/inventory_basic.dat" \
                      "Basic Network Server with Persistence" \
                      "Client connection: ./persistent_requester -h localhost -p 40001 -u 40002" \
                      "/tmp/inventory_basic.dat"
            ;;
        2)
            run_server "./persistent_warehouse -T 40003 -U 40004 -f /tmp/inventory_atoms.dat -c 1000 -o 2000 -H 3000" \
                      "Network Server with Initial Atoms + Persistence" \
                      "Client connection: ./persistent_requester -h localhost -p 40003 -u 40004" \
                      "/tmp/inventory_atoms.dat"
            ;;
        3)
            run_server "./persistent_warehouse -T 40005 -U 40006 -f /tmp/inventory_timeout.dat -t 30" \
                      "Network Server with 30s Timeout + Persistence" \
                      "Client connection: ./persistent_requester -h localhost -p 40005 -u 40006" \
                      "/tmp/inventory_timeout.dat"
            ;;
        4)
            run_server "./persistent_warehouse -s /tmp/stream.sock -d /tmp/datagram.sock -f /tmp/inventory_uds.dat" \
                      "Basic UDS Server with Persistence" \
                      "Client connection: ./persistent_requester -f /tmp/stream.sock -d /tmp/datagram.sock" \
                      "/tmp/inventory_uds.dat"
            ;;
        5)
            run_server "./persistent_warehouse -s /tmp/stream_atoms.sock -d /tmp/datagram_atoms.sock -f /tmp/inventory_uds_atoms.dat -c 1000 -o 2000 -H 3000" \
                      "UDS Server with Initial Atoms + Persistence" \
                      "Client connection: ./persistent_requester -f /tmp/stream_atoms.sock -d /tmp/datagram_atoms.sock" \
                      "/tmp/inventory_uds_atoms.dat"
            ;;
        6)
            run_server "./persistent_warehouse -s /tmp/stream_timeout.sock -d /tmp/datagram_timeout.sock -f /tmp/inventory_uds_timeout.dat -t 30" \
                      "UDS Server with 30s Timeout + Persistence" \
                      "Client connection: ./persistent_requester -f /tmp/stream_timeout.sock -d /tmp/datagram_timeout.sock" \
                      "/tmp/inventory_uds_timeout.dat"
            ;;
        7)
            run_server "./persistent_warehouse -T 40007 -d /tmp/datagram_mixed1.sock -f /tmp/inventory_mixed1.dat" \
                      "Mixed: Network TCP + UDS Datagram + Persistence" \
                      "Client connection: ./persistent_requester -h localhost -p 40007 -d /tmp/datagram_mixed1.sock" \
                      "/tmp/inventory_mixed1.dat"
            ;;
        8)
            run_server "./persistent_warehouse -s /tmp/stream_mixed2.sock -U 40008 -f /tmp/inventory_mixed2.dat" \
                      "Mixed: UDS Stream + Network UDP + Persistence" \
                      "Client connection: ./persistent_requester -f /tmp/stream_mixed2.sock -u 40008" \
                      "/tmp/inventory_mixed2.dat"
            ;;
        9)
            run_server "./persistent_warehouse -T 40009 -U 40010 -f /tmp/inventory_demo.dat -c 10000 -o 15000 -H 20000" \
                      "Demo Server with Large Inventory + Persistence" \
                      "Client connection: ./persistent_requester -h localhost -p 40009 -u 40010" \
                      "/tmp/inventory_demo.dat"
            ;;
        10)
            echo -e "\n${YELLOW}Multi-Process Test${NC}"
            echo "=================="
            echo "This will try to start a second server using an existing inventory file"
            echo "to demonstrate file locking protection."
            echo ""
            echo "Choose an existing inventory file:"
            show_inventory_files
            echo ""
            echo -n "Enter inventory file path: "
            read inventory_file
            
            if [ -f "$inventory_file" ]; then
                echo -e "${BLUE}Starting second server (should be blocked by file locking)...${NC}"
                run_server "./persistent_warehouse -T 40011 -U 40012 -f \"$inventory_file\"" \
                          "Multi-Process Test Server" \
                          "Client connection: ./persistent_requester -h localhost -p 40011 -u 40012" \
                          "$inventory_file"
            else
                echo -e "${RED}File not found: $inventory_file${NC}"
            fi
            ;;
        11)
            echo -e "\n${YELLOW}Custom Configuration${NC}"
            echo "===================="
            echo "Available options:"
            echo "  -T <port>     TCP port"
            echo "  -U <port>     UDP port" 
            echo "  -s <path>     UDS stream socket path"
            echo "  -d <path>     UDS datagram socket path"
            echo "  -f <path>     Save file path (REQUIRED for Q6)"
            echo "  -c <num>      Initial carbon atoms"
            echo "  -o <num>      Initial oxygen atoms"
            echo "  -H <num>      Initial hydrogen atoms"
            echo "  -t <sec>      Timeout seconds"
            echo ""
            echo -e "${RED}Note: -f (save file) is required for Q6!${NC}"
            echo -n "Enter server arguments: "
            read server_args
            
            if [ -n "$server_args" ]; then
                # בדוק אם יש -f בארגומנטים
                if [[ "$server_args" == *"-f"* ]]; then
                    run_server "./persistent_warehouse $server_args" \
                              "Custom Server" \
                              "Use appropriate client options based on server configuration" \
                              "Custom save file"
                else
                    echo -e "${RED}Error: -f (save file) argument is required for Q6!${NC}"
                    echo "Example: -T 12345 -U 12346 -f /tmp/my_inventory.dat"
                fi
            fi
            ;;
        12)
            show_inventory_files
            ;;
        13)
            clean_all_files
            ;;
        14)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            cleanup_files
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read
    cleanup_files
done