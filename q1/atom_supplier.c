/**
 * atom_supplier.c
 *
 * Interactive TCP client for communicating with the atom warehouse server.
 *
 * This client connects to the server on the specified IPv4 address or hostname, and port,
 * provided as command-line arguments.
 *
 * It offers an interactive menu that allows the user to:
 *  - Add a specified number of CARBON, OXYGEN, or HYDROGEN atoms.
 *  - Gracefully disconnect from the server on request.
 *  - Detect if the server has disconnected before sending.
 *
 * Usage:
 *   ./atom_supplier <server_ip_or_hostname> <port>
 *
 * Example:
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

void show_menu() {
    printf("\n=== ATOM SUPPLIER MENU ===\n");
    printf("1. ADD CARBON\n");
    printf("2. ADD OXYGEN\n");
    printf("3. ADD HYDROGEN\n");
    printf("4. QUIT\n");
    printf("Your choice: ");
}

int read_unsigned_long_long(unsigned long long *result) {
    char input[BUFFER_SIZE];
    if (!fgets(input, sizeof(input), stdin)) {
        return 0;  // Input error
    }

    char *endptr;
    errno = 0;
    unsigned long long value = strtoull(input, &endptr, 10);
    if (errno != 0 || endptr == input || (*endptr != '\n' && *endptr != '\0')) {
        return 0;  // Invalid conversion
    }

    *result = value;
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <server_ip_or_hostname> <port>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *server_host = argv[1];
    const char *server_port = argv[2];
    int sockfd;
    struct addrinfo hints, *servinfo, *p;
    int rv;

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;         // IPv4 only
    hints.ai_socktype = SOCK_STREAM;   // TCP

    if ((rv = getaddrinfo(server_host, server_port, &hints, &servinfo)) != 0) {
        fprintf(stderr, "Error resolving server address: %s\n", gai_strerror(rv));
        exit(EXIT_FAILURE);
    }

    for (p = servinfo; p != NULL; p = p->ai_next) {
        sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sockfd == -1) {
            perror("Error creating socket");
            continue;
        }

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            perror("Error connecting to server");
            close(sockfd);
            continue;
        }

        break;  // Successfully connected
    }

    if (p == NULL) {
        fprintf(stderr, "Failed to connect to server.\n");
        freeaddrinfo(servinfo);
        exit(EXIT_FAILURE);
    }

    char host_str[INET_ADDRSTRLEN];
    struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
    inet_ntop(p->ai_family, &(ipv4->sin_addr), host_str, sizeof host_str);
    printf("Connected to server %s on port %s\n", host_str, server_port);

    freeaddrinfo(servinfo);  // Done with address info

    int running = 1;
    char buffer[BUFFER_SIZE];
    char recv_buffer[BUFFER_SIZE];
    while (running) {
        show_menu();
        int choice;
        if (scanf("%d", &choice) != 1) {
            printf("Error: invalid menu choice. Please enter a number.\n");
            while (getchar() != '\n');  // Clear input buffer
            continue;
        }
        while (getchar() != '\n');  // Clear newline character

        unsigned long long amount;
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

        // Check if server closed connection before sending
        int pre_check = recv(sockfd, recv_buffer, sizeof(recv_buffer) - 1, MSG_DONTWAIT);
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

        // Optional: check again if server closed right after sending (for robustness)
        int post_check = recv(sockfd, recv_buffer, sizeof(recv_buffer) - 1, MSG_DONTWAIT);
        if (post_check == 0) {
            printf("Notice: server closed the connection after your command was sent.\n");
            break;
        } else if (post_check < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            perror("Error checking server status after sending");
            break;
        }

        printf("Command sent: %s", buffer);
    }

    close(sockfd);
    printf("Connection closed.\n");
    return 0;
}
