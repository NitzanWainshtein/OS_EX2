/**
 * atom_supplier.c
 *
 * Interactive TCP client for communicating with the atom warehouse server
 * with server response handling and error reporting.
 *
 * This client connects to the server on the specified IPv4 address or hostname, and port,
 * provided as command-line arguments. It features an interactive menu system and
 * displays detailed feedback from the server for all operations.
 * 
 * Usage:
 *   ./atom_supplier <server_ip_or_hostname> <port>
 *
 * Examples:
 *   ./atom_supplier 127.0.0.1 12345
 *   ./atom_supplier myserver.local 12345
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <errno.h>

#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL  // 10^18

/**
 * show_menu
 *
 * Displays the main interactive menu with available operations.
 * Provides clear options for adding different types of atoms or quitting.
 */
void show_menu() {
    printf("\n=== ATOM SUPPLIER MENU ===\n");
    printf("1. ADD CARBON\n");
    printf("2. ADD OXYGEN\n");
    printf("3. ADD HYDROGEN\n");
    printf("4. QUIT\n");
    printf("Your choice: ");
}

/**
 * read_unsigned_long_long
 *
 * Safely reads and validates an unsigned long long integer from user input.
 * Performs comprehensive input validation to prevent buffer overflows and
 * ensure the value is within acceptable numeric ranges.
 *
 * @param result Pointer to store the parsed value
 * @return 1 on success, 0 on failure (invalid input)
 */
int read_unsigned_long_long(unsigned long long *result) {
    char input[BUFFER_SIZE];
    
    // Read line from stdin with bounds checking
    if (!fgets(input, sizeof(input), stdin)) {
        return 0;  // Input error or EOF
    }

    // Parse string to unsigned long long with error checking
    char *endptr;
    errno = 0;
    unsigned long long value = strtoull(input, &endptr, 10);
    
    // Validate conversion was successful and complete
    if (errno != 0 || endptr == input || (*endptr != '\n' && *endptr != '\0')) {
        return 0;  // Invalid conversion
    }

    *result = value;
    return 1;
}

/**
 * read_server_response
 *
 * Reads and displays all available server responses using non-blocking I/O
 *
 * The function uses select() with a timeout to detect when the server has
 * finished sending response data, then displays all received messages to
 * the user in a formatted manner.
 *
 * @param sockfd Socket file descriptor for server connection
 */
void read_server_response(int sockfd) {
    char recv_buffer[BUFFER_SIZE];
    fd_set read_fds;
    struct timeval timeout;
    
    while (1) {
        FD_ZERO(&read_fds);
        FD_SET(sockfd, &read_fds);
        
        // Set timeout, to allow server to send multiple messages
        timeout.tv_sec = 0;
        timeout.tv_usec = 500000;
        
        // Check if data is available for reading
        int activity = select(sockfd + 1, &read_fds, NULL, NULL, &timeout);
        
        if (activity > 0 && FD_ISSET(sockfd, &read_fds)) {
            // Data available - read it
            int nbytes = recv(sockfd, recv_buffer, sizeof(recv_buffer) - 1, MSG_DONTWAIT);
            if (nbytes > 0) {
                recv_buffer[nbytes] = '\0';
                printf("Server: %s", recv_buffer);
            } else if (nbytes == 0) {
                printf("Server disconnected.\n");
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                perror("Error receiving from server");
                break;
            }
        } else {
            // Timeout reached - server finished sending responses
            break;
        }
    }
}

/**
 * main
 *
 * Client entry point. Establishes connection to server using hostname resolution,
 * presents interactive menu, handles user input, and manages communication
 * with the server including comprehensive error handling.
 *
 * @param argc Argument count
 * @param argv Argument vector - expects server address and port
 * @return Exit status
 */
int main(int argc, char *argv[]) {
    // Validate command line arguments
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <server_ip_or_hostname> <port>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *server_host = argv[1];
    const char *server_port = argv[2];
    int sockfd;
    struct addrinfo hints, *servinfo, *p;
    int rv;

    // Configure address resolution hints
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;         // IPv4 only
    hints.ai_socktype = SOCK_STREAM;   // TCP

    // Resolve server hostname/IP address
    if ((rv = getaddrinfo(server_host, server_port, &hints, &servinfo)) != 0) {
        fprintf(stderr, "Error resolving server address: %s\n", gai_strerror(rv));
        exit(EXIT_FAILURE);
    }

    // Attempt to connect to resolved addresses
    for (p = servinfo; p != NULL; p = p->ai_next) {
        // Create socket
        sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sockfd == -1) {
            perror("Error creating socket");
            continue;
        }

        // Attempt connection
        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            perror("Error connecting to server");
            close(sockfd);
            continue;
        }

        break;  // Successfully connected
    }

    // Check if connection was successful
    if (p == NULL) {
        fprintf(stderr, "Failed to connect to server.\n");
        freeaddrinfo(servinfo);
        exit(EXIT_FAILURE);
    }

    // Display connection information
    char host_str[INET_ADDRSTRLEN];
    struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
    inet_ntop(p->ai_family, &(ipv4->sin_addr), host_str, sizeof host_str);
    printf("Connected to server %s on port %s\n", host_str, server_port);

    freeaddrinfo(servinfo);  // Clean up address info

    // Main client loop
    int running = 1;
    char buffer[BUFFER_SIZE];
    
    while (running) {
        show_menu();
        
        // Read and validate menu choice
        int choice;
        if (scanf("%d", &choice) != 1) {
            printf("Error: invalid menu choice. Please enter a number.\n");
            while (getchar() != '\n');  // Clear input buffer
            continue;
        }
        while (getchar() != '\n');  // Clear newline character

        unsigned long long amount;
        
        // Process menu selection
        switch (choice) {
            case 1:
                printf("Enter amount of CARBON to add (max %llu): ", MAX_ATOMS);
                if (!read_unsigned_long_long(&amount) || amount > MAX_ATOMS) {
                    printf("Error: invalid or too large number. Please try again.\n");
                    continue;
                }
                snprintf(buffer, sizeof(buffer), "ADD CARBON %llu\n", amount);
                break;
                
            case 2:
                printf("Enter amount of OXYGEN to add (max %llu): ", MAX_ATOMS);
                if (!read_unsigned_long_long(&amount) || amount > MAX_ATOMS) {
                    printf("Error: invalid or too large number. Please try again.\n");
                    continue;
                }
                snprintf(buffer, sizeof(buffer), "ADD OXYGEN %llu\n", amount);
                break;
                
            case 3:
                printf("Enter amount of HYDROGEN to add (max %llu): ", MAX_ATOMS);
                if (!read_unsigned_long_long(&amount) || amount > MAX_ATOMS) {
                    printf("Error: invalid or too large number. Please try again.\n");
                    continue;
                }
                snprintf(buffer, sizeof(buffer), "ADD HYDROGEN %llu\n", amount);
                break;
                
            case 4:
                printf("Disconnecting from server.\n");
                running = 0;
                continue;
                
            default:
                printf("Invalid menu option. Please select 1–4.\n");
                continue;
        }

        // Check if server closed connection before sending (optional pre-check)
        int pre_check = recv(sockfd, buffer, sizeof(buffer) - 1, MSG_DONTWAIT);
        if (pre_check == 0) {
            printf("Notice: server closed the connection before you could send your command.\n");
            break;
        } else if (pre_check < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            perror("Error checking server status before sending");
            break;
        }

        // Send command to server
        if (send(sockfd, buffer, strlen(buffer), 0) == -1) {
            perror("Error sending data to server");
            break;
        }

        printf("Command sent: %s", buffer);
        
        // Read and display all server responses
        printf("\n--- Server Response ---\n");
        read_server_response(sockfd);
        printf("----------------------\n");
    }

    // Clean up and exit
    close(sockfd);
    printf("Connection closed.\n");
    return 0;
}