/**
 * persistent_warehouse.c - Q6
 * 
 * Warehouse server with persistent storage and multiple process support
 * Enhanced with proper client feedback and strict input validation
 * 
 * Features:
 * - Persistent storage using memory-mapped files
 * - Support for both TCP/UDP and UDS stream/datagram
 * - File locking for concurrent access
 * - Automatic inventory synchronization
 * - Comprehensive error handling
 * - Welcome messages for connecting clients
 * 
 * Usage:
 *   ./persistent_warehouse -T <tcp_port> -U <udp_port> -f <save_file> [options]
 *   ./persistent_warehouse -s <stream_path> -d <datagram_path> -f <save_file> [options]
 * 
 * Options:
 *   -T, --tcp-port PORT         TCP port for stream connections
 *   -U, --udp-port PORT         UDP port for datagram requests
 *   -s, --stream-path PATH      UDS stream socket path
 *   -d, --datagram-path PATH    UDS datagram socket path
 *   -f, --save-file PATH        Save file path (required)
 *   -c, --carbon NUM            Initial carbon atoms (default: 0)
 *   -o, --oxygen NUM            Initial oxygen atoms (default: 0)
 *   -H, --hydrogen NUM          Initial hydrogen atoms (default: 0)
 *   -t, --timeout SEC           Timeout in seconds (default: no timeout)
 * 
 * Commands (TCP/UDS stream):
 *   ADD CARBON <amount>         Add carbon atoms
 *   ADD OXYGEN <amount>         Add oxygen atoms
 *   ADD HYDROGEN <amount>       Add hydrogen atoms
 * 
 * Commands (UDP/UDS datagram):
 *   DELIVER WATER <quantity>             Request water molecules
 *   DELIVER CARBON DIOXIDE <quantity>    Request CO2 molecules
 *   DELIVER ALCOHOL <quantity>           Request alcohol molecules
 *   DELIVER GLUCOSE <quantity>           Request glucose molecules
 * 
 * Admin Commands (stdin):
 *   GEN SOFT DRINK              Calculate possible soft drinks
 *   GEN VODKA                   Calculate possible vodka
 *   GEN CHAMPAGNE               Calculate possible champagne
 *   shutdown                    Shutdown server
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
#include <sys/mman.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>
#include <errno.h>

#define MAX_CLIENTS 10
#define BUFFER_SIZE 256
#define MAX_ATOMS 1000000000000000000ULL

// Global flag for timeout
volatile int timeout_occurred = 0;

// Inventory structure for memory mapping
typedef struct {
    unsigned long long carbon;
    unsigned long long oxygen;
    unsigned long long hydrogen;
    int magic;  // For file validation
} inventory_t;

#define INVENTORY_MAGIC 0x12345678

// Global pointer to memory-mapped inventory
inventory_t *inventory = NULL;
int inventory_fd = -1;
char *save_file_path = NULL;

/**
 * timeout_handler - Handles the alarm signal for server timeout
 * @sig: Signal number (unused but required by signal handler signature)
 * 
 * Sets the global timeout flag to indicate timeout has occurred.
 */
void timeout_handler(int sig) {
    (void)sig;  // Prevent compiler warning
    timeout_occurred = 1;
}

/**
 * min3 - Finds the minimum value among three unsigned long long values
 * @a: First value
 * @b: Second value
 * @c: Third value
 * 
 * Returns: The smallest of the three values
 */
unsigned long long min3(unsigned long long a, unsigned long long b, unsigned long long c) {
    unsigned long long min_ab = (a < b) ? a : b;
    return (min_ab < c) ? min_ab : c;
}

/**
 * show_usage - Displays program usage instructions
 * @program_name: Name of the program executable
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
    printf("  -f, --save-file PATH    Save file path (required)\n");
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
 * @filepath: Path to the inventory file
 * @carbon: Initial carbon atoms (used if file doesn't exist)
 * @oxygen: Initial oxygen atoms (used if file doesn't exist)
 * @hydrogen: Initial hydrogen atoms (used if file doesn't exist)
 * 
 * Creates a new inventory file if it doesn't exist, or loads existing data.
 * The file is memory-mapped for efficient access and automatic synchronization.
 * 
 * Returns: 0 on success, -1 on failure
 */
int init_inventory_file(const char *filepath, unsigned long long carbon, unsigned long long oxygen, unsigned long long hydrogen) {
    // Try to open existing file
    inventory_fd = open(filepath, O_RDWR);
    
    if (inventory_fd == -1) {
        // File doesn't exist, create new one
        printf("Save file doesn't exist, creating new file: %s\n", filepath);
        inventory_fd = open(filepath, O_RDWR | O_CREAT, 0644);
        if (inventory_fd == -1) {
            perror("Failed to create save file");
            return -1;
        }
        
        // Initialize with provided values
        inventory_t init_inventory = {
            .carbon = carbon,
            .oxygen = oxygen,
            .hydrogen = hydrogen,
            .magic = INVENTORY_MAGIC
        };
        
        if (write(inventory_fd, &init_inventory, sizeof(inventory_t)) != sizeof(inventory_t)) {
            perror("Failed to write initial inventory");
            close(inventory_fd);
            return -1;
        }
        
        printf("Initialized inventory with: Carbon=%llu, Oxygen=%llu, Hydrogen=%llu\n", 
               carbon, oxygen, hydrogen);
    } else {
        // File exists, validate it
        printf("Loading existing save file: %s\n", filepath);
        inventory_t test_inventory;
        if (read(inventory_fd, &test_inventory, sizeof(inventory_t)) != sizeof(inventory_t)) {
            printf("Warning: Invalid save file format, reinitializing...\n");
            lseek(inventory_fd, 0, SEEK_SET);
            inventory_t init_inventory = {
                .carbon = carbon,
                .oxygen = oxygen,
                .hydrogen = hydrogen,
                .magic = INVENTORY_MAGIC
            };
            if (write(inventory_fd, &init_inventory, sizeof(inventory_t)) != sizeof(inventory_t)) {
                perror("Failed to reinitialize save file");
                close(inventory_fd);
                return -1;
            }
        } else if (test_inventory.magic != INVENTORY_MAGIC) {
            printf("Warning: Invalid save file magic, reinitializing...\n");
            lseek(inventory_fd, 0, SEEK_SET);
            inventory_t init_inventory = {
                .carbon = carbon,
                .oxygen = oxygen,
                .hydrogen = hydrogen,
                .magic = INVENTORY_MAGIC
            };
            if (write(inventory_fd, &init_inventory, sizeof(inventory_t)) != sizeof(inventory_t)) {
                perror("Failed to reinitialize save file");
                close(inventory_fd);
                return -1;
            }
        } else {
            printf("Loaded inventory: Carbon=%llu, Oxygen=%llu, Hydrogen=%llu\n", 
                   test_inventory.carbon, test_inventory.oxygen, test_inventory.hydrogen);
        }
    }
    
    // Memory map the file
    inventory = mmap(NULL, sizeof(inventory_t), PROT_READ | PROT_WRITE, MAP_SHARED, inventory_fd, 0);
    if (inventory == MAP_FAILED) {
        perror("Failed to memory map inventory file");
        close(inventory_fd);
        return -1;
    }
    
    return 0;
}

/**
 * save_inventory - Ensures inventory changes are written to disk
 * 
 * Forces synchronization of the memory-mapped inventory to disk.
 */
void save_inventory() {
    if (inventory != NULL) {
        // Memory mapped file is automatically synchronized
        if (msync(inventory, sizeof(inventory_t), MS_SYNC) == -1) {
            perror("Warning: Failed to sync inventory to disk");
        }
    }
}

/**
 * cleanup_inventory - Cleans up inventory resources on exit
 * 
 * Unmaps the memory-mapped file and closes the file descriptor.
 * This function is registered with atexit() to ensure proper cleanup.
 */
void cleanup_inventory() {
    if (inventory != NULL) {
        save_inventory();
        munmap(inventory, sizeof(inventory_t));
        inventory = NULL;
    }
    if (inventory_fd != -1) {
        close(inventory_fd);
        inventory_fd = -1;
    }
}

/**
 * lock_inventory - Locks the inventory file for exclusive access
 * 
 * Uses fcntl() with F_SETLKW to obtain an exclusive write lock.
 * This ensures multiple processes don't interfere with each other.
 */
void lock_inventory() {
    if (inventory_fd != -1) {
        struct flock lock;
        lock.l_type = F_WRLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = 0;
        lock.l_len = sizeof(inventory_t);
        
        if (fcntl(inventory_fd, F_SETLKW, &lock) == -1) {
            perror("Warning: Failed to lock inventory file");
        }
    }
}

/**
 * unlock_inventory - Releases the lock on the inventory file
 * 
 * Uses fcntl() with F_UNLCK to release the exclusive lock.
 */
void unlock_inventory() {
    if (inventory_fd != -1) {
        struct flock lock;
        lock.l_type = F_UNLCK;
        lock.l_whence = SEEK_SET;
        lock.l_start = 0;
        lock.l_len = sizeof(inventory_t);
        
        if (fcntl(inventory_fd, F_SETLK, &lock) == -1) {
            perror("Warning: Failed to unlock inventory file");
        }
    }
}

/**
 * process_command - Processes an ADD command from the client
 * @cmd: Command string from client
 * @response_buf: Buffer to store response message
 * @response_size: Size of response buffer
 * 
 * Parses ADD commands and updates the inventory with proper validation.
 * Provides detailed feedback to the client including current status.
 * 
 * Returns: Pointer to the response buffer
 */
char* process_command(char *cmd, char *response_buf, size_t response_size) {
    char type[16];
    unsigned long long amount;

    if (sscanf(cmd, "ADD %15s %llu", type, &amount) == 2) {
        if (amount > MAX_ATOMS) {
            snprintf(response_buf, response_size, "ERROR: Amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            printf("Error: amount too large, max allowed per command is %llu.\n", MAX_ATOMS);
            return response_buf;
        }

        // Variables for status message
        int success = 0;
        unsigned long long final_carbon, final_oxygen, final_hydrogen;

        lock_inventory();
        
        if (strcmp(type, "CARBON") == 0) {
            if (inventory->carbon + amount > MAX_ATOMS) {
                snprintf(response_buf, response_size, "ERROR: Adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed CARBON storage limit (%llu).\n", MAX_ATOMS);
            } else {
                inventory->carbon += amount;
                snprintf(response_buf, response_size, "SUCCESS: Added %llu CARBON. Total CARBON: %llu\n", 
                         amount, inventory->carbon);
                printf("Added %llu CARBON.\n", amount);
                success = 1;
            }
        } else if (strcmp(type, "OXYGEN") == 0) {
            if (inventory->oxygen + amount > MAX_ATOMS) {
                snprintf(response_buf, response_size, "ERROR: Adding this would exceed OXYGEN storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed OXYGEN storage limit (%llu).\n", MAX_ATOMS);
            } else {
                inventory->oxygen += amount;
                snprintf(response_buf, response_size, "SUCCESS: Added %llu OXYGEN. Total OXYGEN: %llu\n", 
                         amount, inventory->oxygen);
                printf("Added %llu OXYGEN.\n", amount);
                success = 1;
            }
        } else if (strcmp(type, "HYDROGEN") == 0) {
            if (inventory->hydrogen + amount > MAX_ATOMS) {
                snprintf(response_buf, response_size, "ERROR: Adding this would exceed HYDROGEN storage limit (%llu).\n", MAX_ATOMS);
                printf("Error: adding this would exceed HYDROGEN storage limit (%llu).\n", MAX_ATOMS);
            } else {
                inventory->hydrogen += amount;
                snprintf(response_buf, response_size, "SUCCESS: Added %llu HYDROGEN. Total HYDROGEN: %llu\n", 
                         amount, inventory->hydrogen);
                printf("Added %llu HYDROGEN.\n", amount);
                success = 1;
            }
        } else {
            snprintf(response_buf, response_size, "ERROR: Unknown atom type: %s\n", type);
            printf("Unknown atom type: %s\n", type);
        }
        
        if (success) {
            save_inventory();
            
            // Copy current values before unlocking
            final_carbon = inventory->carbon;
            final_oxygen = inventory->oxygen;
            final_hydrogen = inventory->hydrogen;
            
            unlock_inventory();
            
            // Add status information to the response
            char status_msg[BUFFER_SIZE];
            snprintf(status_msg, sizeof(status_msg), "Status: CARBON: %llu, OXYGEN: %llu, HYDROGEN: %llu\n", 
                     final_carbon, final_oxygen, final_hydrogen);
            
            size_t current_len = strlen(response_buf);
            if (current_len + strlen(status_msg) < response_size) {
                strcat(response_buf, status_msg);
            }
            
            // Print to server console
            printf("Current warehouse status:\n");
            printf("CARBON: %llu\n", final_carbon);
            printf("OXYGEN: %llu\n", final_oxygen);
            printf("HYDROGEN: %llu\n", final_hydrogen);
        } else {
            unlock_inventory();
        }
    } else {
        snprintf(response_buf, response_size, "ERROR: Invalid command format: %s\n", cmd);
        printf("Invalid command: %s\n", cmd);
    }
    
    return response_buf;
}

/**
 * can_deliver - Checks if the requested molecule can be delivered
 * @molecule: Type of molecule requested
 * @quantity: Number of molecules requested
 * 
 * Validates that sufficient atoms are available and performs the delivery
 * if possible. Updates inventory and saves to disk on successful delivery.
 * 
 * Molecule formulas:
 * - WATER: H2O (2 hydrogen + 1 oxygen)
 * - CARBON DIOXIDE: CO2 (1 carbon + 2 oxygen)
 * - ALCOHOL: C2H6O (2 carbon + 6 hydrogen + 1 oxygen)
 * - GLUCOSE: C6H12O6 (6 carbon + 12 hydrogen + 6 oxygen)
 * 
 * Returns: 1 if successful, 0 if not enough atoms
 */
int can_deliver(const char *molecule, unsigned long long quantity) {
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
    
    lock_inventory();
    
    if (inventory->carbon >= needed_c && inventory->oxygen >= needed_o && inventory->hydrogen >= needed_h) {
        inventory->carbon -= needed_c;
        inventory->oxygen -= needed_o;
        inventory->hydrogen -= needed_h;
        save_inventory();
        unlock_inventory();
        return 1;
    }
    
    unlock_inventory();
    return 0;
}

/**
 * calculate_possible_molecules - Calculates how many molecules can be created
 * @water: Pointer to store maximum water molecules
 * @co2: Pointer to store maximum CO2 molecules
 * @alcohol: Pointer to store maximum alcohol molecules
 * @glucose: Pointer to store maximum glucose molecules
 * 
 * Analyzes current inventory to determine the maximum number of each
 * molecule type that can be produced based on available atoms.
 */
void calculate_possible_molecules(unsigned long long *water, unsigned long long *co2, 
                                  unsigned long long *alcohol, unsigned long long *glucose) {
    lock_inventory();
    
    // WATER: 2H + 1O
    *water = 0;
    if (inventory->hydrogen >= 2 && inventory->oxygen >= 1) {
        unsigned long long from_hydrogen = inventory->hydrogen / 2;
        unsigned long long from_oxygen = inventory->oxygen;
        *water = (from_hydrogen < from_oxygen) ? from_hydrogen : from_oxygen;
    }
    
    // CARBON DIOXIDE: 1C + 2O  
    *co2 = 0;
    if (inventory->carbon >= 1 && inventory->oxygen >= 2) {
        unsigned long long from_carbon = inventory->carbon;
        unsigned long long from_oxygen = inventory->oxygen / 2;
        *co2 = (from_carbon < from_oxygen) ? from_carbon : from_oxygen;
    }
    
    // ALCOHOL: 2C + 6H + 1O
    *alcohol = 0;
    if (inventory->carbon >= 2 && inventory->hydrogen >= 6 && inventory->oxygen >= 1) {
        unsigned long long from_carbon = inventory->carbon / 2;
        unsigned long long from_hydrogen = inventory->hydrogen / 6;
        unsigned long long from_oxygen = inventory->oxygen;
        *alcohol = min3(from_carbon, from_hydrogen, from_oxygen);
    }
    
    // GLUCOSE: 6C + 12H + 6O
    *glucose = 0;
    if (inventory->carbon >= 6 && inventory->hydrogen >= 12 && inventory->oxygen >= 6) {
        unsigned long long from_carbon = inventory->carbon / 6;
        unsigned long long from_hydrogen = inventory->hydrogen / 12;
        unsigned long long from_oxygen = inventory->oxygen / 6;
        *glucose = min3(from_carbon, from_hydrogen, from_oxygen);
    }
    
    unlock_inventory();
}

/**
 * process_drink_command - Processes drink commands from administrator
 * @cmd: Command string from stdin
 * 
 * Handles administrative commands to calculate possible drinks:
 * - GEN SOFT DRINK: needs WATER + CARBON DIOXIDE + ALCOHOL
 * - GEN VODKA: needs WATER + ALCOHOL + GLUCOSE
 * - GEN CHAMPAGNE: needs WATER + CARBON DIOXIDE + GLUCOSE
 */
void process_drink_command(char *cmd) {
    char *newline = strchr(cmd, '\n');
    if (newline) *newline = '\0';
    
    if (strcmp(cmd, "GEN SOFT DRINK") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(&water, &co2, &alcohol, &glucose);
        unsigned long long possible_soft_drinks = min3(water, co2, alcohol);
        printf("Can produce %llu SOFT DRINK(s) (needs: WATER + CARBON DIOXIDE + ALCOHOL)\n", possible_soft_drinks);
        
    } else if (strcmp(cmd, "GEN VODKA") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(&water, &co2, &alcohol, &glucose);
        unsigned long long possible_vodka = min3(water, alcohol, glucose);
        printf("Can produce %llu VODKA(s) (needs: WATER + ALCOHOL + GLUCOSE)\n", possible_vodka);
        
    } else if (strcmp(cmd, "GEN CHAMPAGNE") == 0) {
        unsigned long long water, co2, alcohol, glucose;
        calculate_possible_molecules(&water, &co2, &alcohol, &glucose);
        unsigned long long possible_champagne = min3(water, co2, glucose);
        printf("Can produce %llu CHAMPAGNE(s) (needs: WATER + CARBON DIOXIDE + GLUCOSE)\n", possible_champagne);
        
    } else if (strcmp(cmd, "shutdown") == 0) {
        return;
    } else {
        printf("Unknown command: %s\n", cmd);
        printf("Available commands: GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE, shutdown\n");
    }
}

/**
 * handle_molecule_request - Handles DELIVER requests for molecules
 * @buffer: Request buffer from client
 * @req_fd: Socket file descriptor for response
 * @client_addr: Client address structure
 * @addrlen: Length of client address
 * 
 * Processes molecule delivery requests from UDP/UDS datagram clients.
 * Validates input, attempts delivery, and sends detailed response including
 * current inventory status.
 */
void handle_molecule_request(char *buffer, int req_fd, struct sockaddr *client_addr, socklen_t addrlen) {
    printf("Received molecule request: %s\n", buffer);

    char molecule[64];
    unsigned long long quantity = 1;
    
    int parsed = sscanf(buffer, "DELIVER %63s %llu", molecule, &quantity);
    
    if (parsed >= 1) {
        // Handle "CARBON DIOXIDE" as two words
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
        
        // Strict quantity validation - no defaults for invalid values
        if (quantity == 0 || quantity > MAX_ATOMS) {
            char error_msg[BUFFER_SIZE];
            snprintf(error_msg, sizeof(error_msg), "ERROR: Invalid quantity %llu (must be 1-%llu).\n", quantity, MAX_ATOMS);
            sendto(req_fd, error_msg, strlen(error_msg), 0, client_addr, addrlen);
            printf("Invalid quantity for %s: %llu\n", molecule, quantity);
            return;
        }
        
        if (can_deliver(molecule, quantity)) {
            char success_msg[BUFFER_SIZE];
            if (quantity == 1) {
                snprintf(success_msg, sizeof(success_msg), 
                        "SUCCESS: Molecule delivered successfully.\n");
            } else {
                snprintf(success_msg, sizeof(success_msg), 
                        "SUCCESS: Delivered %llu %s successfully.\n", quantity, molecule);
            }
            
            // Add current status to response
            lock_inventory();
            unsigned long long c = inventory->carbon;
            unsigned long long o = inventory->oxygen;
            unsigned long long h = inventory->hydrogen;
            unlock_inventory();
            
            char status_msg[BUFFER_SIZE];
            snprintf(status_msg, sizeof(status_msg), "Status: CARBON: %llu, OXYGEN: %llu, HYDROGEN: %llu\n", c, o, h);
            
            if (strlen(success_msg) + strlen(status_msg) < BUFFER_SIZE) {
                strcat(success_msg, status_msg);
            }
            
            sendto(req_fd, success_msg, strlen(success_msg), 0, client_addr, addrlen);
            printf("Delivered %llu %s.\n", quantity, molecule);
            
            printf("Current warehouse status:\n");
            printf("CARBON: %llu\n", c);
            printf("OXYGEN: %llu\n", o);
            printf("HYDROGEN: %llu\n", h);
        } else {
            char fail_msg[] = "ERROR: Not enough atoms for this molecule.\n";
            sendto(req_fd, fail_msg, strlen(fail_msg), 0, client_addr, addrlen);
            printf("Failed to deliver %llu %s: insufficient atoms.\n", quantity, molecule);
        }
    } else {
        char error_msg[] = "ERROR: Invalid DELIVER command.\n";
        sendto(req_fd, error_msg, strlen(error_msg), 0, client_addr, addrlen);
        printf("Invalid request command.\n");
    }
}

/**
 * main - Main server function
 * @argc: Argument count
 * @argv: Argument vector
 * 
 * Initializes the persistent warehouse server with the following features:
 * - Command-line argument parsing
 * - Persistent inventory file management
 * - Multiple socket types (TCP/UDP, UDS stream/datagram)
 * - Concurrent client handling using select()
 * - Administrative command processing
 * - Graceful shutdown handling
 * 
 * Returns: 0 on success, non-zero on error
 */
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
    
    // Save file is required
    if (!save_file_path) {
        fprintf(stderr, "Error: Save file path is required (-f option)\n");
        show_usage(argv[0]);
        exit(EXIT_FAILURE);
    }
    
    // Check that we have either network ports or UDS paths
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
    
    // Initialize inventory file
    if (init_inventory_file(save_file_path, carbon, oxygen, hydrogen) == -1) {
        fprintf(stderr, "Error: Failed to initialize inventory file\n");
        exit(EXIT_FAILURE);
    }
    
    // Setup cleanup on exit
    atexit(cleanup_inventory);
    
    // Setup timeout if specified
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
    printf("Save file: %s\n", save_file_path);
    printf("Current atoms - Carbon: %llu, Oxygen: %llu, Hydrogen: %llu\n", 
           inventory->carbon, inventory->oxygen, inventory->hydrogen);
    
    // Initialize sockets
    int tcp_fd = -1, udp_fd = -1, uds_stream_fd = -1, uds_datagram_fd = -1;
    int new_fd, fdmax = STDIN_FILENO;
    fd_set master_set, read_fds;
    
    // TCP socket
    if (tcp_port != -1) {
        struct sockaddr_in tcp_addr;
        tcp_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (tcp_fd < 0) { perror("TCP socket error"); exit(1); }
        
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
        unlink(stream_path);
        
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
        unlink(datagram_path);
        
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
                    // New stream connection
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
                                    inventory->carbon, inventory->oxygen, inventory->hydrogen);
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
                                    inventory->carbon, inventory->oxygen, inventory->hydrogen);
                            send(new_fd, welcome_msg, strlen(welcome_msg), 0);
                        }
                    }
                } else if (i == udp_fd || i == uds_datagram_fd) {
                    // Handle datagram request
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
                        handle_molecule_request(buffer, udp_fd, (struct sockaddr*)&client_addr, addrlen);
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
                        handle_molecule_request(buffer, uds_datagram_fd, (struct sockaddr*)&client_addr, addrlen);
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
                            break;
                        } else {
                            process_drink_command(input);
                        }
                    }
                } else {
                    // Handle stream client data
                    char buffer[BUFFER_SIZE];
                    char response[BUFFER_SIZE];
                    int nbytes = recv(i, buffer, sizeof(buffer) - 1, 0);
                    if (nbytes <= 0) {
                        if (nbytes == 0) printf("Socket %d hung up\n", i);
                        else perror("recv");
                        close(i);
                        FD_CLR(i, &master_set);
                    } else {
                        buffer[nbytes] = '\0';
                        process_command(buffer, response, sizeof(response));
                        send(i, response, strlen(response), 0);
                    }
                }
            }
        }
    }
    
    // Cleanup
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
    if (save_file_path) free(save_file_path);
    
    printf("Server terminated. Inventory saved.\n");
    return 0;
}