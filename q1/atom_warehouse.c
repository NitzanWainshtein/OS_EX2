/**
 * atom_warehouse.c
 *
 * TCP server for managing an atom warehouse with client feedback.
 *
 * This server listens for incoming client connections on a specified port
 * (provided as a command-line argument), processes commands to add CARBON,
 * OXYGEN, or HYDROGEN atoms, maintains warehouse status, and provides detailed
 * feedback to clients about command execution results.
 * 
 * Usage:
 *   ./atom_warehouse <port>
 *
 * Example:
 *   ./atom_warehouse 12345
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define MAX_CLIENTS 10                // Maximum concurrent clients
#define BUFFER_SIZE 256               // General buffer size
#define MAX_ATOMS 1000000000000000000ULL  // Max atoms allowed per type (10^18)

/**
 * process_command
 *
 * Processes an ADD command from a client and sends detailed feedback.
 * 
 * This function parses the incoming command, validates the parameters,
 * updates the warehouse inventory if valid, and sends appropriate response
 * messages back to the client.
 *
 * @param client_fd Socket file descriptor for the client connection
 * @param cmd The command string received from the client
 * @param carbon Pointer to the carbon atom count
 * @param oxygen Pointer to the oxygen atom count  
 * @param hydrogen Pointer to the hydrogen atom count
 *
 * Response Format:
 *  - Error: "ERROR: <descriptive error message>\n"
 *  - Success: "SUCCESS: Added X ATOM_TYPE. Total ATOM_TYPE: Y\n"
 *  - Status: "Warehouse status - CARBON: X, OXYGEN: Y, HYDROGEN: Z\n"
 */
void process_command(int client_fd, char *cmd, unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen) {
    char type[16];
    unsigned long long amount;
    char response[BUFFER_SIZE];

    // Parse the ADD command: "ADD <TYPE> <AMOUNT>"
    if (sscanf(cmd, "ADD %15s %llu", type, &amount) == 2) {
        
        // Validate amount doesn't exceed per-command limit
        if (amount > MAX_ATOMS) {
            snprintf(response, sizeof(response), "ERROR: Amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            printf("Error: amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            send(client_fd, response, strlen(response), 0);
            return;
        }

        // Process based on atom type
        if (strcmp(type, "CARBON") == 0) {
            // Check if addition would exceed storage capacity
            if (*carbon + amount > MAX_ATOMS) {
                snprintf(response, sizeof(response), "ERROR: Adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                send(client_fd, response, strlen(response), 0);
                return;
            }
            *carbon += amount;
            snprintf(response, sizeof(response), "SUCCESS: Added %llu CARBON. Total CARBON: %llu\n", amount, *carbon);
            printf("Added %llu CARBON.\n", amount);
            
        } else if (strcmp(type, "OXYGEN") == 0) {
            // Check if addition would exceed storage capacity
            if (*oxygen + amount > MAX_ATOMS) {
                snprintf(response, sizeof(response), "ERROR: Adding this would exceed OXYGEN storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed OXYGEN storage limit (%llu).\n", MAX_ATOMS);
                send(client_fd, response, strlen(response), 0);
                return;
            }
            *oxygen += amount;
            snprintf(response, sizeof(response), "SUCCESS: Added %llu OXYGEN. Total OXYGEN: %llu\n", amount, *oxygen);
            printf("Added %llu OXYGEN.\n", amount);
            
        } else if (strcmp(type, "HYDROGEN") == 0) {
            // Check if addition would exceed storage capacity
            if (*hydrogen + amount > MAX_ATOMS) {
                snprintf(response, sizeof(response), "ERROR: Adding this would exceed HYDROGEN storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed HYDROGEN storage limit (%llu).\n", MAX_ATOMS);
                send(client_fd, response, strlen(response), 0);
                return;
            }
            *hydrogen += amount;
            snprintf(response, sizeof(response), "SUCCESS: Added %llu HYDROGEN. Total HYDROGEN: %llu\n", amount, *hydrogen);
            printf("Added %llu HYDROGEN.\n", amount);
            
        } else {
            // Unknown atom type
            snprintf(response, sizeof(response), "ERROR: Unknown atom type: %s\n", type);
            printf("Unknown atom type: %s\n", type);
            send(client_fd, response, strlen(response), 0);
            return;
        }
    } else {
        // Invalid command format
        snprintf(response, sizeof(response), "ERROR: Invalid command format: %s", cmd);
        printf("Invalid command: %s\n", cmd);
        send(client_fd, response, strlen(response), 0);
        return;
    }

    // Send success response to client
    send(client_fd, response, strlen(response), 0);
    
    // Print current status to server console
    printf("Current warehouse status:\n");
    printf("CARBON: %llu\n", *carbon);
    printf("OXYGEN: %llu\n", *oxygen);
    printf("HYDROGEN: %llu\n", *hydrogen);
    
    // Send current warehouse status to client
    char status_msg[BUFFER_SIZE];
    snprintf(status_msg, sizeof(status_msg), "Warehouse status - CARBON: %llu, OXYGEN: %llu, HYDROGEN: %llu\n", 
             *carbon, *oxygen, *hydrogen);
    send(client_fd, status_msg, strlen(status_msg), 0);
}

/**
 * main
 *
 * Server entry point. Sets up TCP socket, binds to specified port,
 * and enters main event loop using select() for handling multiple
 * client connections and admin commands simultaneously.
 *
 * @param argc Argument count
 * @param argv Argument vector - expects port number as argv[1]
 * @return Exit status
 */
int main(int argc, char *argv[]) {
    // Validate command line arguments
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    // Parse and validate port number
    int port = atoi(argv[1]);
    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Invalid port number: %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    // Server socket variables
    int server_fd, new_fd, fdmax;
    struct sockaddr_in server_addr;
    fd_set master_set, read_fds;

    // Initialize warehouse inventory
    unsigned long long carbon = 0, oxygen = 0, hydrogen = 0;

    // Create TCP socket
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket error");
        exit(1);
    }

    // Configure server address structure
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;  // Accept connections on any interface
    server_addr.sin_port = htons(port);
    memset(&(server_addr.sin_zero), '\0', 8);

    // Bind socket to address and port
    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("bind");
        exit(1);
    }

    // Start listening for incoming connections
    if (listen(server_fd, MAX_CLIENTS) < 0) {
        perror("listen");
        exit(1);
    }

    // Initialize file descriptor sets for select()
    FD_ZERO(&master_set);
    FD_SET(server_fd, &master_set);     // Monitor server socket for new connections
    FD_SET(STDIN_FILENO, &master_set);  // Monitor stdin for admin commands
    fdmax = (server_fd > STDIN_FILENO) ? server_fd : STDIN_FILENO;

    printf("Server listening on port %d...\n", port);
    printf("Type 'shutdown' to stop the server.\n");

    // Main server event loop
    while (1) {
        read_fds = master_set;  // Copy master set for select()
        
        // Wait for activity on any monitored file descriptor
        if (select(fdmax + 1, &read_fds, NULL, NULL, NULL) == -1) {
            perror("select");
            exit(1);
        }

        // Check each file descriptor for activity
        for (int i = 0; i <= fdmax; i++) {
            if (FD_ISSET(i, &read_fds)) {
                
                if (i == server_fd) {
                    // New client connection
                    struct sockaddr_in client_addr;
                    socklen_t addrlen = sizeof(client_addr);
                    new_fd = accept(server_fd, (struct sockaddr*)&client_addr, &addrlen);
                    if (new_fd == -1) {
                        perror("accept");
                    } else {
                        // Add new client to monitoring set
                        FD_SET(new_fd, &master_set);
                        if (new_fd > fdmax) fdmax = new_fd;
                        printf("New connection from %s on socket %d\n", inet_ntoa(client_addr.sin_addr), new_fd);
                    }
                    
                } else if (i == STDIN_FILENO) {
                    // Admin input from server console
                    char input[BUFFER_SIZE];
                    if (fgets(input, sizeof(input), stdin)) {
                        if (strncmp(input, "shutdown", 8) == 0) {
                            printf("Shutdown command received. Closing server.\n");
                            // Close all sockets and exit
                            for (int j = 0; j <= fdmax; j++) {
                                if (FD_ISSET(j, &master_set)) {
                                    close(j);
                                }
                            }
                            exit(0);
                        }
                    }
                    
                } else {
                    // Data from existing client connection
                    char buffer[BUFFER_SIZE];
                    int nbytes = recv(i, buffer, sizeof(buffer) - 1, 0);
                    if (nbytes <= 0) {
                        // Client disconnected or error
                        if (nbytes == 0) {
                            printf("Socket %d hung up\n", i);
                        } else {
                            perror("recv");
                        }
                        close(i);
                        FD_CLR(i, &master_set);  // Remove from monitoring set
                    } else {
                        // Process client command
                        buffer[nbytes] = '\0';  // Null-terminate received data
                        process_command(i, buffer, &carbon, &oxygen, &hydrogen);
                    }
                }
            }
        }
    }

    return 0;
}