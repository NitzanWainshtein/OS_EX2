/**
 * persistent_requester.c - Q6 Client
 * 
 * Enhanced client with UDS support for both stream and datagram communication
 * Features proper server response handling and comprehensive input validation
 * 
 * Features:
 * - Support for both network (TCP/UDP) and UDS (stream/datagram) connections
 * - Interactive menu system for atom management and molecule requests
 * - Comprehensive input validation with proper error handling
 * - Real-time server response display including inventory status
 * - Graceful connection handling and cleanup
 * 
 * Usage:
 *   Network mode:
 *     ./persistent_requester -h <hostname/IP> -p <tcp_port> [-u <udp_port>]
 *   UDS mode:
 *     ./persistent_requester -f <UDS_stream_path> [-d <UDS_datagram_path>]
 * 
 * Options:
 *   -h, --host HOST         Server hostname or IP address
 *   -p, --port PORT         TCP port for stream connection
 *   -u, --udp-port PORT     UDP port for datagram requests (enables molecule menu)
 *   -f, --file PATH         UDS stream socket file path
 *   -d, --datagram PATH     UDS datagram socket file path (enables molecule menu)
 * 
 * Interactive Commands:
 *   1. Add atoms           - Add CARBON, OXYGEN, or HYDROGEN atoms
 *   2. Request molecules   - Request WATER, CO2, ALCOHOL, or GLUCOSE (if enabled)
 *   3. Quit               - Exit the program
 * 
 * Examples:
 *   ./persistent_requester -h 127.0.0.1 -p 12345 -u 12346
 *   ./persistent_requester -f /tmp/stream.sock -d /tmp/datagram.sock
 *   ./persistent_requester -f /tmp/stream.sock
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>

#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

/**
 * show_usage - Displays usage instructions
 * @program_name: Name of the program executable
 */
void show_usage(const char *program_name) {
    printf("Usage: %s [network options] [uds options]\n\n", program_name);
    printf("Network options:\n");
    printf("  -h, --host HOST         Server hostname or IP address\n");
    printf("  -p, --port PORT         TCP port\n");
    printf("  -u, --udp-port PORT     UDP port (enables molecule requests)\n\n");
    printf("UDS options:\n");
    printf("  -f, --file PATH         UDS stream socket file path\n");
    printf("  -d, --datagram PATH     UDS datagram socket file path (enables molecule requests)\n");
    printf("\nExamples:\n");
    printf("  %s -h 127.0.0.1 -p 12345 -u 12346\n", program_name);
    printf("  %s -f /tmp/stream.sock -d /tmp/datagram.sock\n", program_name);
    printf("  %s -f /tmp/stream.sock\n", program_name);
}

/**
 * show_main_menu - Displays the main menu
 * @molecule_enabled: Whether molecule requests are available
 */
void show_main_menu(int molecule_enabled) {
    printf("\n=== PERSISTENT WAREHOUSE CLIENT ===\n");
    printf("1. Add atoms\n");
    if (molecule_enabled) printf("2. Request molecule delivery\n");
    printf("3. Quit\n");
    printf("Your choice: ");
}

/**
 * show_atom_menu - Displays the atoms menu
 */
void show_atom_menu() {
    printf("\n--- ADD ATOMS ---\n");
    printf("1. CARBON\n2. OXYGEN\n3. HYDROGEN\n4. Back\nYour choice: ");
}

/**
 * show_molecule_menu - Displays the molecules menu
 */
void show_molecule_menu() {
    printf("\n--- REQUEST MOLECULE ---\n");
    printf("1. WATER\n2. CARBON DIOXIDE\n3. ALCOHOL\n4. GLUCOSE\n5. Back\nYour choice: ");
}

/**
 * read_unsigned_long_long - Reads a positive number from user
 * @result: Pointer to store the result
 * 
 * Validates user input to ensure it's a valid positive number.
 * 
 * Returns: 1 on success, 0 on failure
 */
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

/**
 * hostname_to_ip - Converts hostname to IP address
 * @hostname: Hostname or IP address string
 * @ip: Buffer to store the resolved IP address
 * 
 * Uses gethostbyname() to resolve hostnames to IP addresses.
 * If the input is already an IP address, it's copied directly.
 * 
 * Returns: 0 on success, -1 on failure
 */
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

/**
 * is_shutdown_message - Checks if the server is shutting down
 * @msg: Message from server
 * 
 * Detects shutdown messages from the server to handle graceful disconnection.
 * 
 * Returns: 1 if shutdown message detected, 0 otherwise
 */
int is_shutdown_message(const char *msg) {
    return (strstr(msg, "shutting down") != NULL || 
            strstr(msg, "shutdown") != NULL ||
            strstr(msg, "closing") != NULL);
}

/**
 * wait_for_additional_messages - Waits for additional server messages
 * @stream_fd: Stream socket file descriptor
 * @timeout_ms: Timeout in milliseconds
 * 
 * Uses select() to wait for additional messages from the server with a timeout.
 * This helps capture status updates and multi-part responses.
 * 
 * Returns: 1 if additional data is available, 0 if timeout
 */
int wait_for_additional_messages(int stream_fd, int timeout_ms) {
    fd_set read_fds;
    struct timeval timeout;
    
    FD_ZERO(&read_fds);
    FD_SET(stream_fd, &read_fds);
    timeout.tv_sec = timeout_ms / 1000;
    timeout.tv_usec = (timeout_ms % 1000) * 1000;
    
    return select(stream_fd + 1, &read_fds, NULL, NULL, &timeout) > 0;
}

int main(int argc, char *argv[]) {
    // Configuration variables
    char *server_host = NULL;
    int tcp_port = -1, udp_port = -1;
    char *uds_stream_path = NULL, *uds_datagram_path = NULL;
    int use_uds = 0, use_network = 0;
    
    // Parse arguments
    int opt;
    while ((opt = getopt(argc, argv, "h:p:u:f:d:")) != -1) {
        switch (opt) {
            case 'h':
                server_host = optarg;
                use_network = 1;
                break;
            case 'p':
                tcp_port = atoi(optarg);
                if (tcp_port <= 0 || tcp_port > 65535) {
                    fprintf(stderr, "Error: Invalid TCP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                use_network = 1;
                break;
            case 'u':
                udp_port = atoi(optarg);
                if (udp_port <= 0 || udp_port > 65535) {
                    fprintf(stderr, "Error: Invalid UDP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                use_network = 1;
                break;
            case 'f':
                uds_stream_path = optarg;
                use_uds = 1;
                break;
            case 'd':
                uds_datagram_path = optarg;
                use_uds = 1;
                break;
            default:
                show_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }
    
    // Validate arguments
    if (use_uds && use_network) {
        fprintf(stderr, "Error: Cannot use both UDS socket files and network address/port\n");
        exit(EXIT_FAILURE);
    }
    
    if (use_network) {
        if (!server_host || tcp_port == -1) {
            fprintf(stderr, "Error: Server hostname/IP and TCP port are required for network connection\n");
            show_usage(argv[0]);
            exit(EXIT_FAILURE);
        }
        if (udp_port != -1 && tcp_port == udp_port) {
            fprintf(stderr, "Error: TCP and UDP ports must be different\n");
            exit(EXIT_FAILURE);
        }
    } else if (use_uds) {
        if (!uds_stream_path) {
            fprintf(stderr, "Error: UDS stream socket file path is required (-f option)\n");
            show_usage(argv[0]);
            exit(EXIT_FAILURE);
        }
    } else {
        fprintf(stderr, "Error: Must specify either network connection or UDS connection\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    // Setup connections
    int stream_fd = -1, datagram_fd = -1;
    int molecule_enabled = 0;
    
    if (use_network) {
        // TCP connection using getaddrinfo (as required in specification)
        struct addrinfo hints, *servinfo, *p;
        int rv;
        
        memset(&hints, 0, sizeof hints);
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        
        char port_str[6];
        snprintf(port_str, sizeof(port_str), "%d", tcp_port);
        
        if ((rv = getaddrinfo(server_host, port_str, &hints, &servinfo)) != 0) {
            fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
            exit(EXIT_FAILURE);
        }
        
        // Connection attempt
        for(p = servinfo; p != NULL; p = p->ai_next) {
            if ((stream_fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
                perror("socket");
                continue;
            }
            
            if (connect(stream_fd, p->ai_addr, p->ai_addrlen) == -1) {
                close(stream_fd);
                perror("connect");
                continue;
            }
            
            break;
        }
        
        if (p == NULL) {
            fprintf(stderr, "Failed to connect to server\n");
            freeaddrinfo(servinfo);
            exit(EXIT_FAILURE);
        }
        
        char server_ip[INET_ADDRSTRLEN];
        struct sockaddr_in *addr = (struct sockaddr_in *)p->ai_addr;
        inet_ntop(AF_INET, &(addr->sin_addr), server_ip, INET_ADDRSTRLEN);
        
        freeaddrinfo(servinfo);
        
        printf("Connected to TCP server at %s:%d", server_ip, tcp_port);
        
        // UDP connection (optional)
        if (udp_port != -1) {
            datagram_fd = socket(AF_INET, SOCK_DGRAM, 0);
            if (datagram_fd < 0) {
                perror("UDP socket creation failed");
                close(stream_fd);
                exit(EXIT_FAILURE);
            }
            molecule_enabled = 1;
            printf(", UDP:%d", udp_port);
        }
        printf("\n");
        
    } else {
        // UDS stream connection
        stream_fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (stream_fd < 0) {
            perror("UDS stream socket creation failed");
            exit(EXIT_FAILURE);
        }
        
        struct sockaddr_un stream_addr;
        memset(&stream_addr, 0, sizeof(stream_addr));
        stream_addr.sun_family = AF_UNIX;
        strncpy(stream_addr.sun_path, uds_stream_path, sizeof(stream_addr.sun_path) - 1);
        
        if (connect(stream_fd, (struct sockaddr*)&stream_addr, sizeof(stream_addr)) < 0) {
            perror("UDS stream connection failed");
            close(stream_fd);
            exit(EXIT_FAILURE);
        }
        
        printf("Connected to UDS stream server at %s", uds_stream_path);
        
        // UDS datagram connection (optional)
        if (uds_datagram_path) {
            datagram_fd = socket(AF_UNIX, SOCK_DGRAM, 0);
            if (datagram_fd < 0) {
                perror("UDS datagram socket creation failed");
                close(stream_fd);
                exit(EXIT_FAILURE);
            }
            molecule_enabled = 1;
            printf(", datagram:%s", uds_datagram_path);
        }
        printf("\n");
    }

    // Read and display welcome message
    char recv_buffer[BUFFER_SIZE];
    int n = recv(stream_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
    if (n > 0) {
        recv_buffer[n] = '\0';
        printf("Server: %s", recv_buffer);
    }

    // Main program loop
    int running = 1;
    int server_connected = 1;
    char buffer[BUFFER_SIZE];
    
    while (running && server_connected) {
        show_main_menu(molecule_enabled);
        int choice;
        if (scanf("%d", &choice) != 1) { 
            while (getchar() != '\n'); 
            printf("Invalid input. Please enter a number.\n");
            continue; 
        }
        while (getchar() != '\n');

        if (choice == 1) {
            // Add atoms (via stream connection)
            int atom_choice;
            while (server_connected) {
                show_atom_menu();
                if (scanf("%d", &atom_choice) != 1) { 
                    while (getchar() != '\n'); 
                    printf("Invalid input. Please enter a number.\n");
                    continue; 
                }
                while (getchar() != '\n');

                if (atom_choice == 4) break;

                const char *atom;
                switch (atom_choice) {
                    case 1: atom = "CARBON"; break;
                    case 2: atom = "OXYGEN"; break;
                    case 3: atom = "HYDROGEN"; break;
                    default: 
                        printf("Invalid atom choice (1-4).\n"); 
                        continue;
                }

                printf("Amount to add (max %llu): ", MAX_ATOMS);
                unsigned long long amount;
                if (!read_unsigned_long_long(&amount) || amount == 0 || amount > MAX_ATOMS) {
                    printf("Invalid amount. Please enter a positive number up to %llu.\n", MAX_ATOMS); 
                    continue;
                }

                snprintf(buffer, sizeof(buffer), "ADD %s %llu\n", atom, amount);
                if (send(stream_fd, buffer, strlen(buffer), 0) == -1) {
                    perror("Stream send failed");
                    server_connected = 0;
                    break;
                }
                
                // Receive and display server response
                n = recv(stream_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
                if (n <= 0) {
                    if (n == 0) {
                        printf("Server disconnected.\n");
                    } else {
                        perror("Stream receive failed");
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
                    
                    // Attempt to receive additional messages (like status updates)
                    if (wait_for_additional_messages(stream_fd, 100)) {
                        n = recv(stream_fd, recv_buffer, sizeof(recv_buffer) - 1, 0);
                        if (n > 0) {
                            recv_buffer[n] = '\0';
                            printf("Server: %s", recv_buffer);
                        }
                    }
                }
            }

        } else if (choice == 2 && molecule_enabled && server_connected) {
            // Request molecules (via datagram connection)
            int mol_choice;
            while (server_connected) {
                show_molecule_menu();
                if (scanf("%d", &mol_choice) != 1) { 
                    while (getchar() != '\n'); 
                    printf("Invalid input. Please enter a number.\n");
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
                    default: 
                        printf("Invalid molecule choice (1-5).\n"); 
                        continue;
                }

                // Strict quantity validation - no defaults for invalid values
                unsigned long long quantity;
                while (1) {
                    printf("How many %s molecules to request (1-%llu): ", mol, MAX_ATOMS);
                    if (read_unsigned_long_long(&quantity) && quantity > 0 && quantity <= MAX_ATOMS) {
                        break;
                    }
                    printf("Invalid quantity. Please enter a positive number up to %llu.\n", MAX_ATOMS);
                }

                snprintf(buffer, sizeof(buffer), "DELIVER %s %llu\n", mol, quantity);
                
                if (use_network) {
                    // Send via UDP
                    struct sockaddr_in udp_addr;
                    udp_addr.sin_family = AF_INET;
                    udp_addr.sin_port = htons(udp_port);
                    char server_ip[16];
                    hostname_to_ip(server_host, server_ip);
                    inet_pton(AF_INET, server_ip, &udp_addr.sin_addr);
                    
                    if (sendto(datagram_fd, buffer, strlen(buffer), 0, 
                              (struct sockaddr*)&udp_addr, sizeof(udp_addr)) == -1) {
                        perror("UDP send failed");
                        continue;
                    }
                    
                    n = recvfrom(datagram_fd, recv_buffer, sizeof(recv_buffer) - 1, 0, NULL, NULL);
                    if (n > 0) {
                        recv_buffer[n] = '\0';
                        printf("Server: %s", recv_buffer);
                    } else {
                        perror("UDP receive failed");
                    }
                } else {
                    // Send via UDS datagram
                    struct sockaddr_un dgram_addr;
                    memset(&dgram_addr, 0, sizeof(dgram_addr));
                    dgram_addr.sun_family = AF_UNIX;
                    strncpy(dgram_addr.sun_path, uds_datagram_path, sizeof(dgram_addr.sun_path) - 1);
                    
                    if (sendto(datagram_fd, buffer, strlen(buffer), 0, 
                              (struct sockaddr*)&dgram_addr, sizeof(dgram_addr)) == -1) {
                        perror("UDS datagram send failed");
                        continue;
                    }
                    
                    n = recvfrom(datagram_fd, recv_buffer, sizeof(recv_buffer) - 1, 0, NULL, NULL);
                    if (n > 0) {
                        recv_buffer[n] = '\0';
                        printf("Server: %s", recv_buffer);
                    } else {
                        perror("UDS datagram receive failed");
                    }
                }
            }

        } else if (choice == 3) {
            running = 0;
        } else if (choice == 2 && !molecule_enabled) {
            printf("Molecule requests not available (no datagram connection configured).\n");
        } else {
            printf("Invalid choice. Please select from the available options.\n");
        }
    }

    // Cleanup resources
    if (stream_fd != -1) close(stream_fd);
    if (datagram_fd != -1) close(datagram_fd);
    
    if (!server_connected) {
        printf("Connection to server lost.\n");
    } else {
        printf("Disconnected from server.\n");
    }
    
    return 0;
}