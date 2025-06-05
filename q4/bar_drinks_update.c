/**
 * bar_drinks_update.c - Q4
 * 
 * Advanced warehouse server with command line options, timeout support,
 * and comprehensive client feedback.
 * 
 * Usage:
 *   ./bar_drinks_update -T <tcp_port> -U <udp_port> [options]
 * 
 * Required options:
 *   -T, --tcp-port PORT     TCP port (required)
 *   -U, --udp-port PORT     UDP port (required)
 * 
 * Optional options:
 *   -c, --carbon NUM        Initial carbon atoms (default: 0)
 *   -o, --oxygen NUM        Initial oxygen atoms (default: 0)
 *   -H, --hydrogen NUM      Initial hydrogen atoms (default: 0)
 *   -t, --timeout SEC       Timeout in seconds (default: no timeout)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>

#define MAX_CLIENTS 10
#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

// Global flag for timeout
volatile int timeout_occurred = 0;

// Signal handler for alarm
void timeout_handler(int sig) {
    (void)sig;  // Suppress unused parameter warning
    timeout_occurred = 1;
}

// Helper function to find minimum of three values
unsigned long long min3(unsigned long long a, unsigned long long b, unsigned long long c) {
    unsigned long long min_ab = (a < b) ? a : b;
    return (min_ab < c) ? min_ab : c;
}

void show_usage(const char *program_name) {
    printf("Usage: %s -T <tcp_port> -U <udp_port> [options]\n\n", program_name);
    printf("Required options:\n");
    printf("  -T, --tcp-port PORT     TCP port (required)\n");
    printf("  -U, --udp-port PORT     UDP port (required)\n\n");
    printf("Optional options:\n");
    printf("  -c, --carbon NUM        Initial carbon atoms (default: 0)\n");
    printf("  -o, --oxygen NUM        Initial oxygen atoms (default: 0)\n");
    printf("  -H, --hydrogen NUM      Initial hydrogen atoms (default: 0)\n");
    printf("  -t, --timeout SEC       Timeout in seconds (default: no timeout)\n");
    printf("\nExample:\n");
    printf("  %s -T 12345 -U 12346 -c 100 -o 200 -H 300 -t 60\n", program_name);
}

/**
 * process_command
 *
 * Parses and executes an ADD command received over TCP with detailed client feedback.
 * Supported format: ADD <ATOM_TYPE> <AMOUNT>
 * Updates the warehouse counts if the command is valid.
 * Prints updated warehouse status.
 */
void process_command(int client_fd, char *cmd, unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen) {
    char type[16];
    unsigned long long amount;
    char response[BUFFER_SIZE];

    if (sscanf(cmd, "ADD %15s %llu", type, &amount) == 2) {
        if (amount > MAX_ATOMS) {
            snprintf(response, sizeof(response), "ERROR: Amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            printf("Error: amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            send(client_fd, response, strlen(response), 0);
            return;
        }

        if (strcmp(type, "CARBON") == 0) {
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
            snprintf(response, sizeof(response), "ERROR: Unknown atom type: %s\n", type);
            printf("Unknown atom type: %s\n", type);
            send(client_fd, response, strlen(response), 0);
            return;
        }
    } else {
        snprintf(response, sizeof(response), "ERROR: Invalid command format: %s", cmd);
        printf("Invalid command: %s\n", cmd);
        send(client_fd, response, strlen(response), 0);
        return;
    }

    // Send success response
    send(client_fd, response, strlen(response), 0);
    
    // Print current status to server console
    printf("Current warehouse status:\n");
    printf("CARBON: %llu\n", *carbon);
    printf("OXYGEN: %llu\n", *oxygen);
    printf("HYDROGEN: %llu\n", *hydrogen);
    
    // Send warehouse status to client
    char status_msg[BUFFER_SIZE];
    snprintf(status_msg, sizeof(status_msg), "Status: CARBON: %llu, OXYGEN: %llu, HYDROGEN: %llu\n", 
             *carbon, *oxygen, *hydrogen);
    send(client_fd, status_msg, strlen(status_msg), 0);
}

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
    
    if (*carbon >= needed_c && *oxygen >= needed_o && *hydrogen >= needed_h) {
        *carbon -= needed_c;
        *oxygen -= needed_o;
        *hydrogen -= needed_h;
        return 1;
    }
    
    return 0;
}

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

void process_drink_command(char *cmd, unsigned long long carbon, unsigned long long oxygen, unsigned long long hydrogen) {
    char *newline = strchr(cmd, '\n');
    if (newline) *newline = '\0';
    
    if (strcmp(cmd, "GEN SOFT DRINK") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        unsigned long long possible_soft_drinks = min3(water, co2, alcohol);
        printf("Can produce %llu SOFT DRINK(s) (needs: WATER + CARBON DIOXIDE + ALCOHOL)\n", possible_soft_drinks);
        
    } else if (strcmp(cmd, "GEN VODKA") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        unsigned long long possible_vodka = min3(water, alcohol, glucose);
        printf("Can produce %llu VODKA(s) (needs: WATER + ALCOHOL + GLUCOSE)\n", possible_vodka);
        
    } else if (strcmp(cmd, "GEN CHAMPAGNE") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(carbon, oxygen, hydrogen, &water, &co2, &alcohol, &glucose);
        unsigned long long possible_champagne = min3(water, co2, glucose);
        printf("Can produce %llu CHAMPAGNE(s) (needs: WATER + CARBON DIOXIDE + GLUCOSE)\n", possible_champagne);
        
    } else if (strcmp(cmd, "shutdown") == 0) {
        return;
    } else {
        printf("Unknown command: %s\n", cmd);
        printf("Available commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE, shutdown\n");
    }
}

int main(int argc, char *argv[]) {
    // Default values
    int tcp_port = -1, udp_port = -1;
    unsigned long long carbon = 0, oxygen = 0, hydrogen = 0;
    int timeout_seconds = 0;
    
    // Long options
    static struct option long_options[] = {
        {"tcp-port", required_argument, 0, 'T'},
        {"udp-port", required_argument, 0, 'U'},
        {"carbon", required_argument, 0, 'c'},
        {"oxygen", required_argument, 0, 'o'},
        {"hydrogen", required_argument, 0, 'H'},
        {"timeout", required_argument, 0, 't'},
        {"help", no_argument, 0, '?'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "T:U:c:o:H:t:", long_options, NULL)) != -1) {
        switch (opt) {
            case 'T':
                tcp_port = atoi(optarg);
                if (tcp_port <= 0 || tcp_port > 65535) {
                    fprintf(stderr, "Error: Invalid TCP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'U':
                udp_port = atoi(optarg);
                if (udp_port <= 0 || udp_port > 65535) {
                    fprintf(stderr, "Error: Invalid UDP port: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'c':
                carbon = strtoull(optarg, NULL, 10);
                if (carbon > MAX_ATOMS) {
                    fprintf(stderr, "Error: Initial carbon atoms too large (max: %llu)\n", MAX_ATOMS);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'o':
                oxygen = strtoull(optarg, NULL, 10);
                if (oxygen > MAX_ATOMS) {
                    fprintf(stderr, "Error: Initial oxygen atoms too large (max: %llu)\n", MAX_ATOMS);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'H':
                hydrogen = strtoull(optarg, NULL, 10);
                if (hydrogen > MAX_ATOMS) {
                    fprintf(stderr, "Error: Initial hydrogen atoms too large (max: %llu)\n", MAX_ATOMS);
                    exit(EXIT_FAILURE);
                }
                break;
            case 't':
                timeout_seconds = atoi(optarg);
                if (timeout_seconds <= 0) {
                    fprintf(stderr, "Error: Invalid timeout: %s\n", optarg);
                    exit(EXIT_FAILURE);
                }
                break;
            case '?':
            default:
                show_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }
    
    // Check required arguments
    if (tcp_port == -1) {
        fprintf(stderr, "Error: TCP port is required (-T option)\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    if (udp_port == -1) {
        fprintf(stderr, "Error: UDP port is required (-U option)\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    if (tcp_port == udp_port) {
        fprintf(stderr, "Error: TCP and UDP ports must be different\n");
        exit(EXIT_FAILURE);
    }
    
    // Setup timeout if specified
    if (timeout_seconds > 0) {
        signal(SIGALRM, timeout_handler);
        alarm(timeout_seconds);
        printf("Server will timeout after %d seconds of inactivity\n", timeout_seconds);
    }
    
    printf("Starting Bar Drinks server with:\n");
    printf("TCP port: %d\n", tcp_port);
    printf("UDP port: %d\n", udp_port);
    printf("Initial atoms - Carbon: %llu, Oxygen: %llu, Hydrogen: %llu\n", carbon, oxygen, hydrogen);
    
    // Initialize sockets
    int tcp_fd, udp_fd, new_fd, fdmax;
    struct sockaddr_in tcp_addr, udp_addr;
    fd_set master_set, read_fds;
    
    // TCP socket
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
    
    // UDP socket
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
    
    // Setup select
    FD_ZERO(&master_set);
    FD_SET(tcp_fd, &master_set);
    FD_SET(udp_fd, &master_set);
    FD_SET(STDIN_FILENO, &master_set);
    fdmax = (tcp_fd > udp_fd) ? tcp_fd : udp_fd;
    if (STDIN_FILENO > fdmax) fdmax = STDIN_FILENO;
    
    printf("Server ready. Type 'shutdown' to stop.\n");
    printf("Available drink commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE\n");
    
    // Main loop
    while (1) {
        // Check timeout
        if (timeout_occurred) {
            printf("Timeout occurred. Server shutting down.\n");
            break;
        }
        
        read_fds = master_set;
        if (select(fdmax + 1, &read_fds, NULL, NULL, NULL) == -1) {
            if (timeout_occurred) break;
            perror("select");
            exit(1);
        }
        
        // Reset alarm on activity
        if (timeout_seconds > 0) {
            alarm(timeout_seconds);
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
                } else if (i == udp_fd) {
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
                        
                        // Validate quantity - STRICT validation, NO default fallback
                        if (quantity == 0 || quantity > MAX_ATOMS) {
                            char error_msg[BUFFER_SIZE];
                            snprintf(error_msg, sizeof(error_msg), "ERROR: Invalid quantity %llu (must be 1-%llu).\n", quantity, MAX_ATOMS);
                            sendto(udp_fd, error_msg, strlen(error_msg), 0,
                                   (struct sockaddr*)&client_addr, addrlen);
                            printf("Invalid quantity for %s: %llu\n", molecule, quantity);
                            continue;
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
                            close(udp_fd);
                            printf("Server closed.\n");
                            exit(0);
                        } else {
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
                        process_command(i, buffer, &carbon, &oxygen, &hydrogen);
                    }
                }
            }
        }
    }
    
    // Cleanup
    close(tcp_fd);
    close(udp_fd);
    printf("Server terminated.\n");
    return 0;
}