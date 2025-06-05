/**
 * molecule_requester_update.c - Q4
 *
 * Client with command line options support.
 * Supports both TCP (atoms) and UDP (molecules).
 * Enhanced with proper getaddrinfo usage for hostname resolution.
 * 
 * Usage:
 *   ./molecule_requester_update -h <hostname/IP> -p <tcp_port> [-u <udp_port>]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>

#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

void show_usage(const char *program_name) {
    printf("Usage: %s -h <hostname/IP> -p <tcp_port> [-u <udp_port>]\n\n", program_name);
    printf("Required options:\n");
    printf("  -h <hostname/IP>   Server hostname or IP address\n");
    printf("  -p <tcp_port>      TCP port for atom operations\n\n");
    printf("Optional options:\n");
    printf("  -u <udp_port>      UDP port for molecule operations\n\n");
    printf("Example:\n");
    printf("  %s -h localhost -p 12345 -u 12346\n", program_name);
}

void show_main_menu(int udp_enabled) {
    printf("\n=== MOLECULE REQUESTER MENU ===\n");
    printf("1. Add atoms (TCP)\n");
    if (udp_enabled) printf("2. Request molecule delivery (UDP)\n");
    printf("3. Quit\n");
    printf("Your choice: ");
}

void show_atom_menu() {
    printf("\n--- ADD ATOMS ---\n");
    printf("1. CARBON\n2. OXYGEN\n3. HYDROGEN\n4. Back\nYour choice: ");
}

void show_molecule_menu() {
    printf("\n--- REQUEST MOLECULE ---\n");
    printf("1. WATER\n2. CARBON DIOXIDE\n3. ALCOHOL\n4. GLUCOSE\n5. Back\nYour choice: ");
}

int read_unsigned_long_long(unsigned long long *result) {
    char input[BUFFER_SIZE];
    if (!fgets(input, sizeof(input), stdin)) return 0;
    char *endptr;
    errno = 0;
    unsigned long long value = strtoull(input, &endptr, 10);
    if (errno != 0 || endptr == input || (*endptr != '\n' && *endptr != '\0')) return 0;
    *result = value;
    return 1;
}

// Check if server message indicates shutdown
int is_shutdown_message(const char *msg) {
    return (strstr(msg, "shutting down") != NULL || 
            strstr(msg, "shutdown") != NULL ||
            strstr(msg, "closing") != NULL);
}

int main(int argc, char *argv[]) {
    char *server_host = NULL;
    int tcp_port = -1;
    int udp_port = -1;
    int udp_enabled = 0;
    
    // Parse command line options
    int opt;
    while ((opt = getopt(argc, argv, "h:p:u:")) != -1) {
        switch (opt) {
            case 'h':
                server_host = optarg;
                break;
            case 'p':
                tcp_port = atoi(optarg);
                if (tcp_port <= 0 || tcp_port > 65535) {
                    fprintf(stderr, "Error: Invalid TCP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'u':
                udp_port = atoi(optarg);
                if (udp_port <= 0 || udp_port > 65535) {
                    fprintf(stderr, "Error: Invalid UDP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                udp_enabled = 1;
                break;
            default:
                show_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }
    
    // Validate required arguments
    if (!server_host || tcp_port == -1) {
        fprintf(stderr, "Error: -h and -p are required\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    // TCP connection using getaddrinfo (as required by PDF)
    struct addrinfo hints, *servinfo, *p;
    int rv;
    int tcp_fd = -1;
    
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    
    char port_str[6];
    snprintf(port_str, sizeof(port_str), "%d", tcp_port);
    
    if ((rv = getaddrinfo(server_host, port_str, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        exit(EXIT_FAILURE);
    }
    
    // Try to connect
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((tcp_fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            perror("socket");
            continue;
        }
        
        if (connect(tcp_fd, p->ai_addr, p->ai_addrlen) == -1) {
            close(tcp_fd);
            perror("connect");
            continue;
        }
        
        break;
    }
    
    if (p == NULL) {
        fprintf(stderr, "Failed to connect\n");
        freeaddrinfo(servinfo);
        exit(EXIT_FAILURE);
    }
    
    char server_ip[INET_ADDRSTRLEN];
    struct sockaddr_in *addr = (struct sockaddr_in *)p->ai_addr;
    inet_ntop(AF_INET, &(addr->sin_addr), server_ip, INET_ADDRSTRLEN);
    
    freeaddrinfo(servinfo);
    
    printf("Connected to server at %s:%d", server_ip, tcp_port);
    
    // UDP setup if enabled
    int udp_fd = -1;
    struct sockaddr_in udp_addr;
    if (udp_enabled) {
        udp_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (udp_fd < 0) {
            perror("UDP socket");
            close(tcp_fd);
            exit(EXIT_FAILURE);
        }
        
        // Setup UDP address using same IP as TCP
        memset(&udp_addr, 0, sizeof(udp_addr));
        udp_addr.sin_family = AF_INET;
        udp_addr.sin_port = htons(udp_port);
        udp_addr.sin_addr = addr->sin_addr;
        
        printf(", UDP:%d", udp_port);
    }
    printf("\n");

    // Main loop
    int running = 1;
    int server_connected = 1;
    char buffer[BUFFER_SIZE], recv_buffer[BUFFER_SIZE];
    
    while (running && server_connected) {
        show_main_menu(udp_enabled);
        
        int choice;
        if (scanf("%d", &choice) != 1) { 
            while (getchar() != '\n'); 
            continue; 
        }
        while (getchar() != '\n');

        if (choice == 1) {
            // Add atoms via TCP
            int atom_choice;
            while (server_connected) {
                show_atom_menu();
                if (scanf("%d", &atom_choice) != 1) { 
                    while (getchar() != '\n'); 
                    continue; 
                }
                while (getchar() != '\n');

                if (atom_choice == 4) break;

                const char *atom;
                switch (atom_choice) {
                    case 1: atom = "CARBON"; break;
                    case 2: atom = "OXYGEN"; break;
                    case 3: atom = "HYDROGEN"; break;
                    default: printf("Invalid atom choice.\n"); continue;
                }

                printf("Amount to add (max %llu): ", MAX_ATOMS);
                unsigned long long amount;
                if (!read_unsigned_long_long(&amount) || amount > MAX_ATOMS) {
                    printf("Invalid number.\n"); 
                    continue;
                }

                snprintf(buffer, sizeof(buffer), "ADD %s %llu\n", atom, amount);
                if (send(tcp_fd, buffer, strlen(buffer), 0) == -1) {
                    perror("send");
                    server_connected = 0;
                    break;
                }
                
                // Receive and display server response
                int n = recv(tcp_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
                if (n <= 0) {
                    if (n == 0) printf("Server disconnected.\n");
                    else perror("recv");
                    server_connected = 0;
                    break;
                }
                
                recv_buffer[n] = '\0';
                printf("Server: %s", recv_buffer);
                
                // Check if server is shutting down
                if (is_shutdown_message(recv_buffer)) {
                    printf("Server is shutting down. Disconnecting...\n");
                    server_connected = 0;
                    break;
                }
                
                // Try to receive additional messages (like status update)
                fd_set read_fds;
                struct timeval timeout;
                FD_ZERO(&read_fds);
                FD_SET(tcp_fd, &read_fds);
                timeout.tv_sec = 0;
                timeout.tv_usec = 100000; // 100ms timeout
                
                if (select(tcp_fd + 1, &read_fds, NULL, NULL, &timeout) > 0) {
                    n = recv(tcp_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
                    if (n > 0) {
                        recv_buffer[n] = '\0';
                        printf("Server: %s", recv_buffer);
                    }
                }
            }
            
        } else if (choice == 2 && udp_enabled) {
            // Request molecules via UDP
            int mol_choice;
            while (1) {
                show_molecule_menu();
                if (scanf("%d", &mol_choice) != 1) { 
                    while (getchar() != '\n'); 
                    continue; 
                }
                while (getchar() != '\n');

                if (mol_choice == 5) break;

                const char *mol;
                switch (mol_choice) {
                    case 1: mol = "WATER"; break;
                    case 2: mol = "CARBON DIOXIDE"; break;
                    case 3: mol = "ALCOHOL"; break;
                    case 4: mol = "GLUCOSE"; break;
                    default: printf("Invalid molecule choice.\n"); continue;
                }

                printf("How many %s molecules (1-%llu): ", mol, MAX_ATOMS);
                unsigned long long quantity;
                if (!read_unsigned_long_long(&quantity) || quantity == 0 || quantity > MAX_ATOMS) {
                    printf("Invalid quantity. Please try again.\n");
                    continue;
                }

                snprintf(buffer, sizeof(buffer), "DELIVER %s %llu\n", mol, quantity);
                if (sendto(udp_fd, buffer, strlen(buffer), 0, 
                          (struct sockaddr*)&udp_addr, sizeof(udp_addr)) == -1) {
                    perror("sendto");
                    continue;
                }
                
                int n = recvfrom(udp_fd, recv_buffer, sizeof(recv_buffer) - 1, 0, NULL, NULL);
                if (n > 0) {
                    recv_buffer[n] = '\0';
                    printf("Server: %s", recv_buffer);
                } else {
                    perror("recvfrom");
                }
            }
            
        } else if (choice == 3) {
            running = 0;
        } else {
            printf("Invalid choice.\n");
        }
    }

    close(tcp_fd);
    if (udp_enabled) close(udp_fd);
    
    if (!server_connected) {
        printf("Connection to server lost.\n");
    } else {
        printf("Disconnected.\n");
    }
    
    return 0;
}