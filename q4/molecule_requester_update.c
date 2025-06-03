/**
 * molecule_requester_update.c - Q4
 *
 * Client with command line options support.
 * 
 * Usage:
 *   ./molecule_requester_update -h <hostname/IP> -p <port>
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
#include <errno.h>
#include <netdb.h>

#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

void show_usage(const char *program_name) {
    printf("Usage: %s -h <hostname/IP> -p <port>\n", program_name);
}

void show_atom_menu() {
    printf("\n--- ADD ATOMS ---\n");
    printf("1. CARBON\n2. OXYGEN\n3. HYDROGEN\n4. Back\nYour choice: ");
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

int hostname_to_ip(const char *hostname, char *ip) {
    struct hostent *he;
    struct in_addr addr;
    
    if (inet_aton(hostname, &addr)) {
        strcpy(ip, hostname);
        return 0;
    }
    
    he = gethostbyname(hostname);
    if (he == NULL) {
        return -1;
    }
    
    strcpy(ip, inet_ntoa(*((struct in_addr*)he->h_addr)));
    return 0;
}

int is_shutdown_message(const char *msg) {
    return (strstr(msg, "shutting down") != NULL || 
            strstr(msg, "shutdown") != NULL ||
            strstr(msg, "closing") != NULL);
}

int main(int argc, char *argv[]) {
    char *server_host = NULL;
    int tcp_port = -1;
    
    int opt;
    while ((opt = getopt(argc, argv, "h:p:")) != -1) {
        switch (opt) {
            case 'h':
                server_host = optarg;
                break;
            case 'p':
                tcp_port = atoi(optarg);
                if (tcp_port <= 0 || tcp_port > 65535) {
                    fprintf(stderr, "Error: Invalid port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                break;
            default:
                show_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }
    
    if (!server_host) {
        fprintf(stderr, "Error: Server hostname/IP is required (-h option)\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    if (tcp_port == -1) {
        fprintf(stderr, "Error: Port is required (-p option)\n");
        show_usage(argv[0]);
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

    printf("Connected to server at %s:%d\n", server_ip, tcp_port);

    int running = 1;
    int server_connected = 1;
    char buffer[BUFFER_SIZE], recv_buffer[BUFFER_SIZE];
    
    while (running && server_connected) {
        printf("\n=== ATOM SUPPLIER ===\n");
        printf("1. Add atoms\n");
        printf("2. Quit\n");
        printf("Your choice: ");
        
        int choice;
        if (scanf("%d", &choice) != 1) { 
            while (getchar() != '\n'); 
            continue; 
        }
        while (getchar() != '\n');

        if (choice == 1) {
            // Add atoms
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
                    
                    if (is_shutdown_message(recv_buffer)) {
                        printf("Server is shutting down. Disconnecting...\n");
                        server_connected = 0;
                        break;
                    }
                }
            }

        } else if (choice == 2) {
            running = 0;
        } else {
            printf("Invalid choice.\n");
        }
    }

    close(tcp_fd);
    
    if (!server_connected) {
        printf("Connection to server lost.\n");
    } else {
        printf("Disconnected.\n");
    }
    
    return 0;
}