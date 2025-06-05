/**
 * molecule_requester.c
 *
 * Unified interactive client for communicating with the molecule_supplier server.
 * Enhanced version with proper disconnection detection.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>

#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

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

// Convert hostname to IP address
int hostname_to_ip(const char *hostname, char *ip) {
    struct hostent *he;
    struct in_addr addr;
    
    // First try to see if it's already an IP address
    if (inet_aton(hostname, &addr)) {
        strcpy(ip, hostname);
        return 0;
    }
    
    // Try to resolve hostname
    he = gethostbyname(hostname);
    if (he == NULL) {
        return -1;
    }
    
    strcpy(ip, inet_ntoa(*((struct in_addr*)he->h_addr)));
    return 0;
}

// Check if server message indicates shutdown
int is_shutdown_message(const char *msg) {
    return (strstr(msg, "shutting down") != NULL || 
            strstr(msg, "shutdown") != NULL ||
            strstr(msg, "closing") != NULL);
}

int main(int argc, char *argv[]) {
    if (argc < 3 || argc > 4) {
        fprintf(stderr, "Usage: %s <server_ip_or_hostname> <tcp_port> [udp_port]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *server_host = argv[1];
    int tcp_port = atoi(argv[2]);
    int udp_port = (argc == 4) ? atoi(argv[3]) : 0;
    int udp_enabled = (argc == 4);
    
    if (tcp_port <= 0 || tcp_port > 65535) {
        fprintf(stderr, "Invalid TCP port: %s\n", argv[2]);
        exit(EXIT_FAILURE);
    }
    
    if (udp_enabled && (udp_port <= 0 || udp_port > 65535)) {
        fprintf(stderr, "Invalid UDP port: %s\n", argv[3]);
        exit(EXIT_FAILURE);
    }

    // Resolve hostname to IP
    char server_ip[16];
    if (hostname_to_ip(server_host, server_ip) != 0) {
        fprintf(stderr, "Could not resolve hostname: %s\n", server_host);
        exit(EXIT_FAILURE);
    }

    // TCP setup
    int tcp_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (tcp_fd < 0) {
        perror("TCP socket creation failed");
        exit(EXIT_FAILURE);
    }

    struct sockaddr_in tcp_addr;
    tcp_addr.sin_family = AF_INET;
    tcp_addr.sin_port = htons(tcp_port);
    if (inet_pton(AF_INET, server_ip, &tcp_addr.sin_addr) <= 0) {
        fprintf(stderr, "Invalid IP address: %s\n", server_ip);
        close(tcp_fd);
        exit(EXIT_FAILURE);
    }

    if (connect(tcp_fd, (struct sockaddr*)&tcp_addr, sizeof(tcp_addr)) < 0) {
        perror("TCP connection failed");
        close(tcp_fd);
        exit(EXIT_FAILURE);
    }

    // UDP setup
    int udp_fd = -1;
    struct sockaddr_in udp_addr;
    if (udp_enabled) {
        udp_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (udp_fd < 0) {
            perror("UDP socket creation failed");
            close(tcp_fd);
            exit(EXIT_FAILURE);
        }

        udp_addr.sin_family = AF_INET;
        udp_addr.sin_port = htons(udp_port);
        if (inet_pton(AF_INET, server_ip, &udp_addr.sin_addr) <= 0) {
            fprintf(stderr, "Invalid IP address for UDP: %s\n", server_ip);
            close(tcp_fd);
            close(udp_fd);
            exit(EXIT_FAILURE);
        }
    }

    printf("Connected to server at %s (TCP:%d", server_ip, tcp_port);
    if (udp_enabled) printf(", UDP:%d", udp_port);
    printf(")\n");

    int running = 1;
    int server_connected = 1;  // Track server connection status
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
            // TCP - Add atoms
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
                    perror("TCP send failed");
                    server_connected = 0;
                    break;
                }
                
                int n = recv(tcp_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
                if (n <= 0) {
                    if (n == 0) {
                        printf("Server disconnected.\n");
                    } else {
                        perror("TCP receive failed");
                    }
                    server_connected = 0;
                    break;
                } else {
                    recv_buffer[n] = '\0';
                    printf("Server: %s", recv_buffer);
                    
                    // Check if server is shutting down
                    if (is_shutdown_message(recv_buffer)) {
                        printf("Server is shutting down. Disconnecting...\n");
                        server_connected = 0;
                        break;
                    }
                }
            }

        } else if (choice == 2 && udp_enabled && server_connected) {
            // UDP - Request molecules
            int mol_choice;
            while (server_connected) {
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

                printf("How many %s molecules to request (1-%llu): ", mol, MAX_ATOMS);
                unsigned long long quantity;
                if (!read_unsigned_long_long(&quantity) || quantity == 0 || quantity > MAX_ATOMS) {
                    printf("Invalid quantity. Please try again.\n");
                    continue;
                }

                snprintf(buffer, sizeof(buffer), "DELIVER %s %llu\n", mol, quantity);
                
                if (sendto(udp_fd, buffer, strlen(buffer), 0, 
                          (struct sockaddr*)&udp_addr, sizeof(udp_addr)) == -1) {
                    perror("UDP send failed");
                    continue;
                }
                
                int n = recvfrom(udp_fd, recv_buffer, sizeof(recv_buffer) - 1, 0, NULL, NULL);
                if (n > 0) {
                    recv_buffer[n] = '\0';
                    printf("Server: %s", recv_buffer);
                } else {
                    perror("UDP receive failed");
                    // UDP failures are not necessarily fatal, continue
                }
            }

        } else if (choice == 3) {
            running = 0;
        } else {
            printf("Invalid menu option.\n");
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