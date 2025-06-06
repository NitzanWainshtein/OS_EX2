/**
 * persistent_warehouse.c - Q6
 * 
 * Warehouse server with persistent storage and multiple process support
 * Enhanced with proper client feedback and strict input validation
 * 
 * Usage:
 *   ./persistent_warehouse -T <tcp_port> -U <udp_port> [options]
 *   ./persistent_warehouse -s <stream_path> -d <datagram_path> [options]
 *   ./persistent_warehouse -f <save_file> [options]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>
#include <errno.h>

#define MAX_CLIENTS 10
#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

// Global variable for timeout
volatile int timeout_occurred = 0;

// File handle for inventory file
int inventory_fd = -1;
char *save_file_path = NULL;

/**
 * timeout_handler - handles the timeout signal
 */
void timeout_handler(int sig) {
    (void)sig;  // Prevent compiler warning
    timeout_occurred = 1;
}

/**
 * min3 - finds the minimum among 3 values
 */
unsigned long long min3(unsigned long long a, unsigned long long b, unsigned long long c) {
    unsigned long long min_ab = (a < b) ? a : b;
    return (min_ab < c) ? min_ab : c;
}

/**
 * show_usage - displays usage instructions
 */
void show_usage(const char *program_name) {
    printf("Usage: %s [network options] [uds options] [general options]\n\n", program_name);
    printf("Network options:\n");
    printf("  -T, --tcp-port PORT     TCP port\n");
    printf("  -U, --udp-port PORT     UDP port\n\n");
    printf("UDS options:\n");
    printf("  -s, --stream-path PATH  UDS stream socket path\n");
    printf("  -d, --datagram-path PATH UDS datagram socket path\n\n");
    printf("General options:\n");
    printf("  -f, --save-file PATH    Save file path (optional)\n");
    printf("  -c, --carbon NUM        Initial carbon atoms (default: 0)\n");
    printf("  -o, --oxygen NUM        Initial oxygen atoms (default: 0)\n");
    printf("  -H, --hydrogen NUM      Initial hydrogen atoms (default: 0)\n");
    printf("  -t, --timeout SEC       Timeout in seconds (default: no timeout)\n");
    printf("\nExamples:\n");
    printf("  %s -T 12345 -U 12346 -f /tmp/inventory.dat\n", program_name);
    printf("  %s -s /tmp/stream.sock -d /tmp/datagram.sock -f /tmp/inventory.dat\n", program_name);
}

/**
 * init_inventory_file - Initializes or loads the inventory from a file
 * Returns 0 on success, -1 on failure
 */
int init_inventory_file(const char *filepath, unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen) {
    // If no file path provided, just return
    if (filepath == NULL)
        return 0;
    
    // Try to open existing file
    inventory_fd = open(filepath, O_RDWR);
    
    if (inventory_fd == -1) {
        // File doesn't exist, create it with initial values
        printf("Save file doesn't exist, creating new file: %s\n", filepath);
        inventory_fd = open(filepath, O_RDWR | O_CREAT, 0644);
        if (inventory_fd == -1) {
            perror("Failed to create save file");
            return -1;
        }
        
        // Write initial values
        if (write(inventory_fd, carbon, sizeof(*carbon)) != sizeof(*carbon) ||
            write(inventory_fd, oxygen, sizeof(*oxygen)) != sizeof(*oxygen) ||
            write(inventory_fd, hydrogen, sizeof(*hydrogen)) != sizeof(*hydrogen)) {
            perror("Failed to write initial inventory");
            close(inventory_fd);
            return -1;
        }
        
        printf("Initialized inventory with: Carbon=%llu, Oxygen=%llu, Hydrogen=%llu\n", 
               *carbon, *oxygen, *hydrogen);
    } else {
        // File exists, load values
        printf("Loading existing save file: %s\n", filepath);
        
        // Lock the file for reading
        struct flock lock;
        lock.l_type = F_RDLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = 0;
        lock.l_len = sizeof(*carbon) + sizeof(*oxygen) + sizeof(*hydrogen);
        
        if (fcntl(inventory_fd, F_SETLKW, &lock) == -1) {
            perror("Failed to lock inventory file");
            close(inventory_fd);
            return -1;
        }
        
        // Read carbon
        if (read(inventory_fd, carbon, sizeof(*carbon)) != sizeof(*carbon)) {
            fprintf(stderr, "Warning: Failed to read carbon from file, using default\n");
            // Keep the default value
        }
        
        // Read oxygen
        if (read(inventory_fd, oxygen, sizeof(*oxygen)) != sizeof(*oxygen)) {
            fprintf(stderr, "Warning: Failed to read oxygen from file, using default\n");
            // Keep the default value
        }
        
        // Read hydrogen
        if (read(inventory_fd, hydrogen, sizeof(*hydrogen)) != sizeof(*hydrogen)) {
            fprintf(stderr, "Warning: Failed to read hydrogen from file, using default\n");
            // Keep the default value
        }
        
        // Unlock the file
        lock.l_type = F_UNLCK;
        if (fcntl(inventory_fd, F_SETLK, &lock) == -1) {
            perror("Warning: Failed to unlock inventory file");
        }
        
        printf("Loaded inventory: Carbon=%llu, Oxygen=%llu, Hydrogen=%llu\n", 
               *carbon, *oxygen, *hydrogen);
    }
    
    return 0;
}

/**
 * save_inventory - Saves inventory to the file
 */
void save_inventory(unsigned long long carbon, unsigned long long oxygen, unsigned long long hydrogen) {
    if (inventory_fd == -1)
        return;
    
    // Lock the file for writing
    struct flock lock;
    lock.l_type = F_WRLCK;
    lock.l_whence = SEEK_SET;
    lock.l_start = 0;
    lock.l_len = sizeof(carbon) + sizeof(oxygen) + sizeof(hydrogen);
    
    if (fcntl(inventory_fd, F_SETLKW, &lock) == -1) {
        perror("Failed to lock inventory file");
        return;
    }
    
    // Seek to beginning of file
    if (lseek(inventory_fd, 0, SEEK_SET) == -1) {
        perror("Failed to seek in inventory file");
        return;
    }
    
    // Write inventory
    if (write(inventory_fd, &carbon, sizeof(carbon)) != sizeof(carbon) ||
        write(inventory_fd, &oxygen, sizeof(oxygen)) != sizeof(oxygen) ||
        write(inventory_fd, &hydrogen, sizeof(hydrogen)) != sizeof(hydrogen)) {
        perror("Failed to write inventory");
    }
    
    // Unlock the file
    lock.l_type = F_UNLCK;
    if (fcntl(inventory_fd, F_SETLK, &lock) == -1) {
        perror("Warning: Failed to unlock inventory file");
    }
}

/**
 * cleanup_inventory - Cleans up resources
 */
void cleanup_inventory() {
    if (inventory_fd != -1) {
        close(inventory_fd);
        inventory_fd = -1;
    }
    
    if (save_file_path != NULL) {
        free(save_file_path);
        save_file_path = NULL;
    }
}

/**
 * process_command - processes ADD commands received from clients
 * enhanced with detailed feedback to client
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

        int updated = 0;
        if (strcmp(type, "CARBON") == 0) {
            if (*carbon + amount > MAX_ATOMS) {
                snprintf(response, sizeof(response), "ERROR: Adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                send(client_fd, response, strlen(response), 0);
                return;
            }
            *carbon += amount;
            updated = 1;
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
            updated = 1;
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
            updated = 1;
            snprintf(response, sizeof(response), "SUCCESS: Added %llu HYDROGEN. Total HYDROGEN: %llu\n", amount, *hydrogen);
            printf("Added %llu HYDROGEN.\n", amount);
        } else {
            snprintf(response, sizeof(response), "ERROR: Unknown atom type: %s\n", type);
            printf("Unknown atom type: %s\n", type);
            send(client_fd, response, strlen(response), 0);
            return;
        }
        
        // Save to file if inventory was updated
        if (updated && inventory_fd != -1) {
            save_inventory(*carbon, *oxygen, *hydrogen);
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

/**
 * can_deliver - checks and performs molecule delivery
 * returns 1 on success, 0 on failure
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
    
    if (*carbon >= needed_c && *oxygen >= needed_o && *hydrogen >= needed_h) {
        *carbon -= needed_c;
        *oxygen -= needed_o;
        *hydrogen -= needed_h;
        
        // Save updated inventory to file
        if (inventory_fd != -1) {
            save_inventory(*carbon, *oxygen, *hydrogen);
        }
        
        return 1;
    }
    
    return 0;
}

/**
 * calculate_possible_molecules - calculates how many molecules can be produced
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
 * process_drink_command - processes drink commands from administrator
 */
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
        // Server will handle shutdown in main loop
        return;
    } else {
        printf("Unknown command: %s\n", cmd);
        printf("Available commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE, shutdown\n");
    }
}

/**
 * handle_molecule_request - handles molecule requests via UDP/UDS datagram
 */
void handle_molecule_request(char *buffer, int req_fd, void *client_addr, socklen_t addrlen, 
                           unsigned long long *carbon, unsigned long long *oxygen, unsigned long long *hydrogen, int is_uds) {
    printf("Received molecule request: %s\n", buffer);

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
        
        // Strict quantity validation
        if (quantity == 0 || quantity > MAX_ATOMS) {
            char error_msg[BUFFER_SIZE];
            snprintf(error_msg, sizeof(error_msg), "ERROR: Invalid quantity %llu (must be 1-%llu).\n", quantity, MAX_ATOMS);
            sendto(req_fd, error_msg, strlen(error_msg), 0, (struct sockaddr*)client_addr, addrlen);
            printf("Invalid quantity for %s: %llu\n", molecule, quantity);
            return;
        }
        
        if (can_deliver(molecule, quantity, carbon, oxygen, hydrogen)) {
            char success_msg[BUFFER_SIZE];
            if (quantity == 1) {
                snprintf(success_msg, sizeof(success_msg), 
                        "Molecule delivered successfully.\n");
            } else {
                snprintf(success_msg, sizeof(success_msg), 
                        "Delivered %llu %s successfully.\n", quantity, molecule);
            }
            
            sendto(req_fd, success_msg, strlen(success_msg), 0, (struct sockaddr*)client_addr, addrlen);
            printf("Delivered %llu %s.\n", quantity, molecule);
            
            printf("Current warehouse status:\n");
            printf("CARBON: %llu\n", *carbon);
            printf("OXYGEN: %llu\n", *oxygen);
            printf("HYDROGEN: %llu\n", *hydrogen);
        } else {
            char fail_msg[] = "Not enough atoms for this molecule.\n";
            sendto(req_fd, fail_msg, strlen(fail_msg), 0, (struct sockaddr*)client_addr, addrlen);
            printf("Failed to deliver %llu %s: insufficient atoms.\n", quantity, molecule);
        }
    } else {
        char error_msg[] = "Invalid DELIVER command.\n";
        sendto(req_fd, error_msg, strlen(error_msg), 0, (struct sockaddr*)client_addr, addrlen);
        printf("Invalid request command.\n");
    }
}

int main(int argc, char *argv[]) {
    // Default values
    int tcp_port = -1, udp_port = -1;
    char *stream_path = NULL, *datagram_path = NULL;
    unsigned long long carbon = 0, oxygen = 0, hydrogen = 0;
    int timeout_seconds = 0;
    
    // Long options
    static struct option long_options[] = {
        {"tcp-port", required_argument, 0, 'T'},
        {"udp-port", required_argument, 0, 'U'},
        {"stream-path", required_argument, 0, 's'},
        {"datagram-path", required_argument, 0, 'd'},
        {"save-file", required_argument, 0, 'f'},
        {"carbon", required_argument, 0, 'c'},
        {"oxygen", required_argument, 0, 'o'},
        {"hydrogen", required_argument, 0, 'H'},
        {"timeout", required_argument, 0, 't'},
        {"help", no_argument, 0, '?'},
        {0, 0, 0, 0}
    };
    
    // Parse arguments
    int opt;
    while ((opt = getopt_long(argc, argv, "T:U:s:d:f:c:o:H:t:", long_options, NULL)) != -1) {
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
            case 's':
                stream_path = strdup(optarg);
                break;
            case 'd':
                datagram_path = strdup(optarg);
                break;
            case 'f':
                save_file_path = strdup(optarg);
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
    
    // Check that we have either ports or UDS paths
    int has_network = (tcp_port != -1) || (udp_port != -1);
    int has_uds = (stream_path != NULL) || (datagram_path != NULL);
    
    if (!has_network && !has_uds) {
        fprintf(stderr, "Error: Must specify either network ports (-T/-U) or UDS paths (-s/-d)\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    if (tcp_port != -1 && udp_port != -1 && tcp_port == udp_port) {
        fprintf(stderr, "Error: TCP and UDP ports must be different\n");
        exit(EXIT_FAILURE);
    }
    
    // Initialize inventory from file if save_file_path is provided
    if (save_file_path != NULL) {
        if (init_inventory_file(save_file_path, &carbon, &oxygen, &hydrogen) != 0) {
            fprintf(stderr, "Error: Failed to initialize inventory file\n");
            exit(EXIT_FAILURE);
        }
        
        // Register cleanup function
        atexit(cleanup_inventory);
    }
    
    // Set timeout if needed
    if (timeout_seconds > 0) {
        signal(SIGALRM, timeout_handler);
        alarm(timeout_seconds);
        printf("Server will timeout after %d seconds of inactivity\n", timeout_seconds);
    }
    
    printf("Starting Persistent Warehouse server with:\n");
    if (tcp_port != -1) printf("TCP port: %d\n", tcp_port);
    if (udp_port != -1) printf("UDP port: %d\n", udp_port);
    if (stream_path) printf("UDS stream path: %s\n", stream_path);
    if (datagram_path) printf("UDS datagram path: %s\n", datagram_path);
    if (save_file_path) printf("Save file: %s\n", save_file_path);
    printf("Initial atoms - Carbon: %llu, Oxygen: %llu, Hydrogen: %llu\n", carbon, oxygen, hydrogen);
    
    // Initialize sockets
    int tcp_fd = -1, udp_fd = -1, uds_stream_fd = -1, uds_datagram_fd = -1;
    int new_fd, fdmax = STDIN_FILENO;
    fd_set master_set, read_fds;
    
    // TCP socket
    if (tcp_port != -1) {
        struct sockaddr_in tcp_addr;
        tcp_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (tcp_fd < 0) { perror("TCP socket error"); exit(1); }
        
        int reuse = 1;
        setsockopt(tcp_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
        
        tcp_addr.sin_family = AF_INET;
        tcp_addr.sin_addr.s_addr = INADDR_ANY;
        tcp_addr.sin_port = htons(tcp_port);
        
        if (bind(tcp_fd, (struct sockaddr*)&tcp_addr, sizeof(tcp_addr)) < 0) {
            perror("TCP bind");
            exit(1);
        }
        if (listen(tcp_fd, MAX_CLIENTS) < 0) {
            perror("TCP listen");
            exit(1);
        }
        if (tcp_fd > fdmax) fdmax = tcp_fd;
    }
    
    // UDP socket
    if (udp_port != -1) {
        struct sockaddr_in udp_addr;
        udp_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (udp_fd < 0) { perror("UDP socket error"); exit(1); }
        
        udp_addr.sin_family = AF_INET;
        udp_addr.sin_addr.s_addr = INADDR_ANY;
        udp_addr.sin_port = htons(udp_port);
        
        if (bind(udp_fd, (struct sockaddr*)&udp_addr, sizeof(udp_addr)) < 0) {
            perror("UDP bind");
            exit(1);
        }
        if (udp_fd > fdmax) fdmax = udp_fd;
    }
    
    // UDS stream socket
    if (stream_path) {
        struct sockaddr_un stream_addr;
        unlink(stream_path); // Remove existing socket file
        
        uds_stream_fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (uds_stream_fd < 0) { perror("UDS stream socket error"); exit(1); }
        
        memset(&stream_addr, 0, sizeof(stream_addr));
        stream_addr.sun_family = AF_UNIX;
        strncpy(stream_addr.sun_path, stream_path, sizeof(stream_addr.sun_path) - 1);
        
        if (bind(uds_stream_fd, (struct sockaddr*)&stream_addr, sizeof(stream_addr)) < 0) {
            perror("UDS stream bind");
            exit(1);
        }
        if (listen(uds_stream_fd, MAX_CLIENTS) < 0) {
            perror("UDS stream listen");
            exit(1);
        }
        if (uds_stream_fd > fdmax) fdmax = uds_stream_fd;
    }
    
    // UDS datagram socket
    if (datagram_path) {
        struct sockaddr_un datagram_addr;
        unlink(datagram_path); // Remove existing socket file
        
        uds_datagram_fd = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (uds_datagram_fd < 0) { perror("UDS datagram socket error"); exit(1); }
        
        memset(&datagram_addr, 0, sizeof(datagram_addr));
        datagram_addr.sun_family = AF_UNIX;
        strncpy(datagram_addr.sun_path, datagram_path, sizeof(datagram_addr.sun_path) - 1);
        
        if (bind(uds_datagram_fd, (struct sockaddr*)&datagram_addr, sizeof(datagram_addr)) < 0) {
            perror("UDS datagram bind");
            exit(1);
        }
        if (uds_datagram_fd > fdmax) fdmax = uds_datagram_fd;
    }
    
    // Setup select
    FD_ZERO(&master_set);
    if (tcp_fd != -1) FD_SET(tcp_fd, &master_set);
    if (udp_fd != -1) FD_SET(udp_fd, &master_set);
    if (uds_stream_fd != -1) FD_SET(uds_stream_fd, &master_set);
    if (uds_datagram_fd != -1) FD_SET(uds_datagram_fd, &master_set);
    FD_SET(STDIN_FILENO, &master_set);
    
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
                if (i == tcp_fd || i == uds_stream_fd) {
                    // New stream connection (TCP or UDS)
                    if (i == tcp_fd) {
                        struct sockaddr_in client_addr;
                        socklen_t addrlen = sizeof(client_addr);
                        new_fd = accept(tcp_fd, (struct sockaddr*)&client_addr, &addrlen);
                        if (new_fd == -1) {
                            perror("TCP accept");
                        } else {
                            FD_SET(new_fd, &master_set);
                            if (new_fd > fdmax) fdmax = new_fd;
                            printf("New TCP connection from %s on socket %d\n",
                                   inet_ntoa(client_addr.sin_addr), new_fd);
                            
                            // Send welcome message
                            char welcome_msg[BUFFER_SIZE];
                            snprintf(welcome_msg, sizeof(welcome_msg), 
                                    "Connected to Persistent Warehouse Server (TCP). Current inventory: C=%llu, O=%llu, H=%llu\n", 
                                    carbon, oxygen, hydrogen);
                            send(new_fd, welcome_msg, strlen(welcome_msg), 0);
                        }
                    } else {
                        struct sockaddr_un client_addr;
                        socklen_t addrlen = sizeof(client_addr);
                        new_fd = accept(uds_stream_fd, (struct sockaddr*)&client_addr, &addrlen);
                        if (new_fd == -1) {
                            perror("UDS stream accept");
                        } else {
                            FD_SET(new_fd, &master_set);
                            if (new_fd > fdmax) fdmax = new_fd;
                            printf("New UDS stream connection on socket %d\n", new_fd);
                            
                            // Send welcome message
                            char welcome_msg[BUFFER_SIZE];
                            snprintf(welcome_msg, sizeof(welcome_msg), 
                                    "Connected to Persistent Warehouse Server (UDS). Current inventory: C=%llu, O=%llu, H=%llu\n", 
                                    carbon, oxygen, hydrogen);
                            send(new_fd, welcome_msg, strlen(welcome_msg), 0);
                        }
                    }
                } else if (i == udp_fd || i == uds_datagram_fd) {
                    // Handle datagram request (UDP or UDS)
                    char buffer[BUFFER_SIZE];
                    
                    if (i == udp_fd) {
                        struct sockaddr_in client_addr;
                        socklen_t addrlen = sizeof(client_addr);
                        int nbytes = recvfrom(udp_fd, buffer, sizeof(buffer) - 1, 0,
                                              (struct sockaddr*)&client_addr, &addrlen);
                        if (nbytes < 0) {
                            perror("UDP recvfrom");
                            continue;
                        }
                        buffer[nbytes] = '\0';
                        handle_molecule_request(buffer, udp_fd, &client_addr, addrlen, 
                                              &carbon, &oxygen, &hydrogen, 0);
                    } else {
                        struct sockaddr_un client_addr;
                        socklen_t addrlen = sizeof(client_addr);
                        int nbytes = recvfrom(uds_datagram_fd, buffer, sizeof(buffer) - 1, 0,
                                              (struct sockaddr*)&client_addr, &addrlen);
                        if (nbytes < 0) {
                            perror("UDS datagram recvfrom");
                            continue;
                        }
                        buffer[nbytes] = '\0';
                        handle_molecule_request(buffer, uds_datagram_fd, &client_addr, addrlen, 
                                              &carbon, &oxygen, &hydrogen, 1);
                    }
                } else if (i == STDIN_FILENO) {
                    // Handle admin input
                    char input[BUFFER_SIZE];
                    if (fgets(input, sizeof(input), stdin)) {
                        if (strncmp(input, "shutdown", 8) == 0) {
                            printf("Shutdown command received. Notifying clients...\n");
                            for (int j = 0; j <= fdmax; j++) {
                                if (FD_ISSET(j, &master_set) && j != tcp_fd && j != udp_fd && 
                                    j != uds_stream_fd && j != uds_datagram_fd && j != STDIN_FILENO) {
                                    send(j, "Server shutting down.\n", strlen("Server shutting down.\n"), 0);
                                    close(j);
                                }
                            }
                            goto shutdown_cleanup; // Clean exit from loop
                        } else {
                            process_drink_command(input, carbon, oxygen, hydrogen);
                        }
                    }
                } else {
                    // Handle stream client data (TCP or UDS)
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
    
shutdown_cleanup:
    // Cleanup resources
    if (tcp_fd != -1) close(tcp_fd);
    if (udp_fd != -1) close(udp_fd);
    if (uds_stream_fd != -1) {
        close(uds_stream_fd);
        if (stream_path) unlink(stream_path);
    }
    if (uds_datagram_fd != -1) {
        close(uds_datagram_fd);
        if (datagram_path) unlink(datagram_path);
    }
    
    if (stream_path) free(stream_path);
    if (datagram_path) free(datagram_path);
    
    printf("Server terminated.\n");
    if (save_file_path) {
        printf("Inventory saved to %s.\n", save_file_path);
    }
    
    return 0;
}