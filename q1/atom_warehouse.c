/**
 * atom_warehouse.c
 *
 * TCP server for managing an atom warehouse.
 *
 * This server listens for incoming client connections on a specified port
 * (provided as a command-line argument), processes commands to add CARBON,
 * OXYGEN, or HYDROGEN atoms, maintains warehouse status, and can be gracefully
 * shut down by the admin.
 *
 * Key features:
 *  - Multi-client handling using select().
 *  - Tracking warehouse atom counts (with overflow protection).
 *  - Graceful shutdown when the admin types "shutdown" in the server terminal.
 *
 * Usage:
 *   ./atom_warehouse <port>
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

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int port = atoi(argv[1]);
    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Invalid port number: %s\n", argv[1]);
        exit(EXIT_FAILURE);
    }

    int server_fd, new_fd, fdmax;
    struct sockaddr_in server_addr;
    fd_set master_set, read_fds;

    unsigned long long carbon = 0, oxygen = 0, hydrogen = 0;

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket error");
        exit(1);
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);
    memset(&(server_addr.sin_zero), '\0', 8);

    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("bind");
        exit(1);
    }

    if (listen(server_fd, MAX_CLIENTS) < 0) {
        perror("listen");
        exit(1);
    }

    FD_ZERO(&master_set);
    FD_SET(server_fd, &master_set);
    FD_SET(STDIN_FILENO, &master_set);
    fdmax = (server_fd > STDIN_FILENO) ? server_fd : STDIN_FILENO;

    printf("Server listening on port %d...\n", port);
    printf("Type 'shutdown' to stop the server.\n");

    while (1) {
        read_fds = master_set;
        if (select(fdmax + 1, &read_fds, NULL, NULL, NULL) == -1) {
            perror("select");
            exit(1);
        }

        for (int i = 0; i <= fdmax; i++) {
            if (FD_ISSET(i, &read_fds)) {
                if (i == server_fd) {
                    struct sockaddr_in client_addr;
                    socklen_t addrlen = sizeof(client_addr);
                    new_fd = accept(server_fd, (struct sockaddr*)&client_addr, &addrlen);
                    if (new_fd == -1) {
                        perror("accept");
                    } else {
                        FD_SET(new_fd, &master_set);
                        if (new_fd > fdmax) fdmax = new_fd;
                        printf("New connection from %s on socket %d\n", inet_ntoa(client_addr.sin_addr), new_fd);
                    }
                } else if (i == STDIN_FILENO) {
                    char input[BUFFER_SIZE];
                    if (fgets(input, sizeof(input), stdin)) {
                        if (strncmp(input, "shutdown", 8) == 0) {
                            printf("Shutdown command received. Closing server.\n");
                            for (int j = 0; j <= fdmax; j++) {
                                if (FD_ISSET(j, &master_set)) {
                                    close(j);
                                }
                            }
                            exit(0);
                        }
                    }
                } else {
                    char buffer[BUFFER_SIZE];
                    int nbytes = recv(i, buffer, sizeof(buffer) - 1, 0);
                    if (nbytes <= 0) {
                        if (nbytes == 0) {
                            printf("Socket %d hung up\n", i);
                        } else {
                            perror("recv");
                        }
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
