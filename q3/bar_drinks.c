/**
 * bar_drinks.c
 *
 * Enhanced warehouse server that also functions as a bar.
 * Supports all previous functionality plus drink generation calculations.
 *
 * Features:
 * - Accepts TCP connections for adding atoms (ADD CARBON/OXYGEN/HYDROGEN).
 * - Accepts UDP requests for molecule delivery (DELIVER WATER, DELIVER ALCOHOL, etc.).
 * - Accepts keyboard commands for drink generation calculations (GEN SOFT DRINK, etc.).
 * - Manages atom counts with overflow protection.
 * - Handles multiple simultaneous clients using select().
 * - Gracefully shuts down when admin types 'shutdown', notifying TCP clients before closing.
 *
 * Usage:
 *   ./bar_drinks <tcp_port> [udp_port]
 *
 * Example:
 *   ./bar_drinks 12345 12346
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/select.h>

#define MAX_CLIENTS 10
#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

// Helper function to find minimum of three values
unsigned long long min3(unsigned long long a, unsigned long long b, unsigned long long c) {
    unsigned long long min_ab = (a < b) ? a : b;
    return (min_ab < c) ? min_ab : c;
}

/**
 * process_command
 *
 * Parses and executes an ADD command received over TCP.
 * Supported format: ADD <ATOM_TYPE> <AMOUNT>
 * Updates the warehouse counts if the command is valid.
 * Prints updated warehouse status.
 */
void process_command(char *cmd, unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen) {
    char type[16];
    unsigned long long amount;

    if (sscanf(cmd, "ADD %15s %llu", type, &amount) == 2) {
        if (amount > MAX_ATOMS) {
            printf("Error: amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            return;
        }

        if (strcmp(type, "CARBON") == 0) {
            if (*carbon + amount > MAX_ATOMS) {
                printf("Error: adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                return;
            }
            *carbon += amount;
            printf("Added %llu CARBON.\n", amount);
        } else if (strcmp(type, "OXYGEN") == 0) {
            if (*oxygen + amount > MAX_ATOMS) {
                printf("Error: adding this would exceed OXYGEN storage limit (%llu).\n", MAX_ATOMS);
                return;
            }
            *oxygen += amount;
            printf("Added %llu OXYGEN.\n", amount);
        } else if (strcmp(type, "HYDROGEN") == 0) {
            if (*hydrogen + amount > MAX_ATOMS) {
                printf("Error: adding this would exceed HYDROGEN storage limit (%llu).\n", MAX_ATOMS);
                return;
            }
            *hydrogen += amount;
            printf("Added %llu HYDROGEN.\n", amount);
        } else {
            printf("Unknown atom type: %s\n", type);
            return;
        }
    } else {
        printf("Invalid command: %s\n", cmd);
        return;
    }

    printf("Current warehouse status:\n");
    printf("CARBON: %llu\n", *carbon);
    printf("OXYGEN: %llu\n", *oxygen);
    printf("HYDROGEN: %llu\n", *hydrogen);
}

/**
 * can_deliver
 *
 * Checks if molecules can be delivered based on available atoms.
 * If delivery is possible, updates warehouse counts.
 *
 * Supported molecules:
 * - WATER (2 H + 1 O)
 * - CARBON DIOXIDE (1 C + 2 O) 
 * - ALCOHOL (2 C + 6 H + 1 O)
 * - GLUCOSE (6 C + 12 H + 6 O)
 */
int can_deliver(const char *molecule, unsigned long long quantity, unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen) {
    unsigned long long needed_c = 0, needed_o = 0, needed_h = 0;
    
    if (strcmp(molecule, "WATER") == 0) {
        needed_h = 2 * quantity;
        needed_o = 1 * quantity;
    } else if (strcmp(molecule, "CARBON DIOXIDE") == 0) {
        needed_c = 1 * quantity;
        needed_o = 2 * quantity;
    } else if (strcmp(molecule, "ALCOHOL") == 0) {
        needed_c = 2 * quantity;
        needed_h = 6 * quantity;
        needed_o = 1 * quantity;
    } else if (strcmp(molecule, "GLUCOSE") == 0) {
        needed_c = 6 * quantity;
        needed_h = 12 * quantity;
        needed_o = 6 * quantity;
    } else {
        return 0; // Unknown molecule
    }
    
    // Check if we have enough atoms
    if (*carbon >= needed_c && *oxygen >= needed_o && *hydrogen >= needed_h) {
        *carbon -= needed_c;
        *oxygen -= needed_o;
        *hydrogen -= needed_h;
        return 1;
    }
    
    return 0;
}

/**
 * calculate_possible_molecules
 *
 * Calculates how many of each molecule type can be produced from current atoms.
 */
void calculate_possible_molecules(unsigned long long carbon, unsigned long long oxygen, unsigned long long hydrogen,
                                 unsigned long long *water, unsigned long long *co2, 
                                 unsigned long long *alcohol, unsigned long long *glucose) {
    
    // WATER: 2H + 1O
    *water = 0;
    if (hydrogen >= 2 && oxygen >= 1) {
        unsigned long long from_hydrogen = hydrogen / 2;
        unsigned long long from_oxygen = oxygen;
        *water = (from_hydrogen < from_oxygen) ? from_hydrogen : from_oxygen;
    }
    
    // CARBON DIOXIDE: 1C + 2O  
    *co2 = 0;
    if (carbon >= 1 && oxygen >= 2) {
        unsigned long long from_carbon = carbon;
        unsigned long long from_oxygen = oxygen / 2;
        *co2 = (from_carbon < from_oxygen) ? from_carbon : from_oxygen;
    }
    
    // ALCOHOL: 2C + 6H + 1O
    *alcohol = 0;
    if (carbon >= 2 && hydrogen >= 6 && oxygen >= 1) {
        unsigned long long from_carbon = carbon / 2;
        unsigned long long from_hydrogen = hydrogen / 6;
        unsigned long long from_oxygen = oxygen;
        *alcohol = min3(from_carbon, from_hydrogen, from_oxygen);
    }
    
    // GLUCOSE: 6C + 12H + 6O
    *glucose = 0;
    if (carbon >= 6 && hydrogen >= 12 && oxygen >= 6) {
        unsigned long long from_carbon = carbon / 6;
        unsigned long long from_hydrogen = hydrogen / 12;
        unsigned long long from_oxygen = oxygen / 6;
        *glucose = min3(from_carbon, from_hydrogen, from_oxygen);
    }
}

/**
 * process_drink_command
 *
 * Processes drink generation commands from keyboard input.
 * Calculates and displays how many drinks can be made.
 */
void process_drink_command(char *cmd, unsigned long long carbon, unsigned long long oxygen, unsigned long long hydrogen) {
    // Remove newline if present
    char *newline = strchr(cmd, '\n');
    if (newline) *newline = '\0';
    
    if (strcmp(cmd, "GEN SOFT DRINK") == 0) {
        // SOFT DRINK = WATER + CARBON DIOXIDE + ALCOHOL
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        
        unsigned long long possible_soft_drinks = min3(water, co2, alcohol);
        printf("Can produce %llu SOFT DRINK(s) (needs: WATER + CARBON DIOXIDE + ALCOHOL)\n", possible_soft_drinks);
        
    } else if (strcmp(cmd, "GEN VODKA") == 0) {
        // VODKA = WATER + ALCOHOL + GLUCOSE
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        
        unsigned long long possible_vodka = min3(water, alcohol, glucose);
        printf("Can produce %llu VODKA(s) (needs: WATER + ALCOHOL + GLUCOSE)\n", possible_vodka);
        
    } else if (strcmp(cmd, "GEN CHAMPAGNE") == 0) {
        // CHAMPAGNE = WATER + CARBON DIOXIDE + GLUCOSE
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        
        unsigned long long possible_champagne = min3(water, co2, glucose);
        printf("Can produce %llu CHAMPAGNE(s) (needs: WATER + CARBON DIOXIDE + GLUCOSE)\n", possible_champagne);
        
    } else if (strcmp(cmd, "shutdown") == 0) {
        // This will be handled by the main loop
        return;
    } else {
        printf("Unknown command: %s\n", cmd);
        printf("Available commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE, shutdown\n");
    }
}

/**
 * Main server function.
 */
int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: %s <tcp_port> [udp_port]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int tcp_port = atoi(argv[1]);
    if (tcp_port <= 0 || tcp_port > 65535) {
        fprintf(stderr, "Invalid TCP port number: %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    int udp_port = 0, udp_enabled = 0;
    if (argc == 3) {
        udp_port = atoi(argv[2]);
        if (udp_port <= 0 || udp_port > 65535) {
            fprintf(stderr, "Invalid UDP port number: %s\n", argv[2]);
            exit(EXIT_FAILURE);
        }
        if (udp_port == tcp_port) {
            fprintf(stderr, "TCP and UDP ports must be different.\n");
            exit(EXIT_FAILURE);
        }
        udp_enabled = 1;
    }

    int tcp_fd, udp_fd = -1, new_fd, fdmax;
    struct sockaddr_in tcp_addr, udp_addr;
    fd_set master_set, read_fds;
    unsigned long long carbon = 0, oxygen = 0, hydrogen = 0;

    // Initialize TCP socket
    tcp_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (tcp_fd < 0) { perror("TCP socket error"); exit(1); }

    tcp_addr.sin_family = AF_INET;
    tcp_addr.sin_addr.s_addr = INADDR_ANY;
    tcp_addr.sin_port = htons(tcp_port);
    memset(&(tcp_addr.sin_zero), '\0', 8);

    if (bind(tcp_fd, (struct sockaddr*)&tcp_addr, sizeof(tcp_addr)) < 0) {
        perror("TCP bind");
        exit(1);
    }
    if (listen(tcp_fd, MAX_CLIENTS) < 0) {
        perror("TCP listen");
        exit(1);
    }

    // Initialize UDP socket if enabled
    if (udp_enabled) {
        udp_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (udp_fd < 0) { perror("UDP socket error"); exit(1); }
        udp_addr.sin_family = AF_INET;
        udp_addr.sin_addr.s_addr = INADDR_ANY;
        udp_addr.sin_port = htons(udp_port);
        memset(&(udp_addr.sin_zero), '\0', 8);

        if (bind(udp_fd, (struct sockaddr*)&udp_addr, sizeof(udp_addr)) < 0) {
            perror("UDP bind");
            exit(1);
        }
    }

    // Setup select()
    FD_ZERO(&master_set);
    FD_SET(tcp_fd, &master_set);
    FD_SET(STDIN_FILENO, &master_set);
    fdmax = (tcp_fd > STDIN_FILENO) ? tcp_fd : STDIN_FILENO;
    if (udp_enabled) {
        FD_SET(udp_fd, &master_set);
        if (udp_fd > fdmax) fdmax = udp_fd;
    }

    if (udp_enabled) {
        printf("Bar Drinks server running on TCP port %d and UDP port %d\n", tcp_port, udp_port);
    } else {
        printf("Bar Drinks server running on TCP port %d (UDP disabled)\n", tcp_port);
    }
    printf("Available commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE, shutdown\n");

    // Main loop
    while (1) {
        read_fds = master_set;
        if (select(fdmax + 1, &read_fds, NULL, NULL, NULL) == -1) {
            perror("select");
            exit(1);
        }

        for (int i = 0; i <= fdmax; i++) {
            if (FD_ISSET(i, &read_fds)) {
                if (i == tcp_fd) {
                    // New TCP connection
                    struct sockaddr_in client_addr;
                    socklen_t addrlen = sizeof(client_addr);
                    new_fd = accept(tcp_fd, (struct sockaddr*)&client_addr, &addrlen);
                    if (new_fd == -1) {
                        perror("accept");
                    } else {
                        FD_SET(new_fd, &master_set);
                        if (new_fd > fdmax) fdmax = new_fd;
                        printf("New TCP connection from %s on socket %d\n",
                               inet_ntoa(client_addr.sin_addr), new_fd);
                    }
                } else if (udp_enabled && i == udp_fd) {
                    // Handle UDP request
                    char buffer[BUFFER_SIZE];
                    struct sockaddr_in client_addr;
                    socklen_t addrlen = sizeof(client_addr);
                    int nbytes = recvfrom(udp_fd, buffer, sizeof(buffer) - 1, 0,
                                          (struct sockaddr*)&client_addr, &addrlen);
                    if (nbytes < 0) {
                        perror("recvfrom");
                        continue;
                    }
                    buffer[nbytes] = '\0';
                    printf("Received UDP command: %s\n", buffer);

                    char molecule[64];
                    unsigned long long quantity = 1;
                    
                    int parsed = sscanf(buffer, "DELIVER %63s %llu", molecule, &quantity);
                    
                    if (parsed >= 1) {
                        // Handle "CARBON DIOXIDE" as special case (two words)
                        if (strcmp(molecule, "CARBON") == 0) {
                            char dioxide[32];
                            if (sscanf(buffer, "DELIVER CARBON %31s %llu", dioxide, &quantity) >= 2 && 
                                strcmp(dioxide, "DIOXIDE") == 0) {
                                strcpy(molecule, "CARBON DIOXIDE");
                            } else if (sscanf(buffer, "DELIVER CARBON %31s", dioxide) == 1 && 
                                      strcmp(dioxide, "DIOXIDE") == 0) {
                                strcpy(molecule, "CARBON DIOXIDE");
                                quantity = 1;
                            }
                        }
                        
                        if (parsed == 1) {
                            quantity = 1;
                        }
                        
                        if (can_deliver(molecule, quantity, &carbon, &oxygen, &hydrogen)) {
                            char success_msg[BUFFER_SIZE];
                            if (quantity == 1) {
                                snprintf(success_msg, sizeof(success_msg), 
                                        "Molecule delivered successfully.\n");
                            } else {
                                snprintf(success_msg, sizeof(success_msg), 
                                        "Delivered %llu %s successfully.\n", quantity, molecule);
                            }
                            sendto(udp_fd, success_msg, strlen(success_msg), 0,
                                   (struct sockaddr*)&client_addr, addrlen);
                            printf("Delivered %llu %s.\n", quantity, molecule);
                            
                            printf("Current warehouse status:\n");
                            printf("CARBON: %llu\n", carbon);
                            printf("OXYGEN: %llu\n", oxygen);
                            printf("HYDROGEN: %llu\n", hydrogen);
                        } else {
                            char fail_msg[] = "Not enough atoms for this molecule.\n";
                            sendto(udp_fd, fail_msg, strlen(fail_msg), 0,
                                   (struct sockaddr*)&client_addr, addrlen);
                            printf("Failed to deliver %llu %s: insufficient atoms.\n", quantity, molecule);
                        }
                    } else {
                        char error_msg[] = "Invalid DELIVER command.\n";
                        sendto(udp_fd, error_msg, strlen(error_msg), 0,
                               (struct sockaddr*)&client_addr, addrlen);
                        printf("Invalid UDP command.\n");
                    }
                } else if (i == STDIN_FILENO) {
                    // Handle admin input
                    char input[BUFFER_SIZE];
                    if (fgets(input, sizeof(input), stdin)) {
                        if (strncmp(input, "shutdown", 8) == 0) {
                            printf("Shutdown command received. Notifying clients...\n");
                            for (int j = 0; j <= fdmax; j++) {
                                if (FD_ISSET(j, &master_set) && j != tcp_fd && j != udp_fd && j != STDIN_FILENO) {
                                    send(j, "Server shutting down.\n", strlen("Server shutting down.\n"), 0);
                                    close(j);
                                }
                            }
                            close(tcp_fd);
                            if (udp_enabled) close(udp_fd);
                            printf("Server closed.\n");
                            exit(0);
                        } else {
                            // Process drink generation command
                            process_drink_command(input, carbon, oxygen, hydrogen);
                        }
                    }
                } else {
                    // Handle TCP client data
                    char buffer[BUFFER_SIZE];
                    int nbytes = recv(i, buffer, sizeof(buffer) - 1, 0);
                    if (nbytes <= 0) {
                        if (nbytes == 0) printf("Socket %d hung up\n", i);
                        else perror("recv");
                        close(i);
                        FD_CLR(i, &master_set);
                    } else {
                        buffer[nbytes] = '\0';
                        process_command(buffer, &carbon, &oxygen, &hydrogen);
                        send(i, "Command processed.\n", strlen("Command processed.\n"), 0);
                    }
                }
            }
        }
    }

    return 0;
}