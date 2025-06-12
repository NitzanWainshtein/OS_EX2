# Operating Systems Ex2

**Authors:**
- Nitzan Wainshtein, ID: 209086263
- Aviv Oz, ID: 207543927

## Overview

This project implements a comprehensive atom warehouse management system using various network programming and inter-process communication techniques. The system demonstrates client-server architecture, TCP/UDP communication, Unix Domain Sockets (UDS), memory-mapped files, and process synchronization.

## Project Structure

The project is organized into 6 parts (q1-q6), each building upon the previous ones:

```
OS_EX2/
├── q1/           # Basic TCP Client-Server
├── q2/           # Multi-Protocol Server (TCP + UDP)
├── q3/           # Bar Drinks with Admin Commands
├── q4/           # Command Line Options & Timeout
├── q5/           # Unix Domain Sockets Support
├── q6/           # Persistent Storage with Memory Mapping
└── Makefile      # Root build system
```

## Features by Question

### Q1: Basic Atom Warehouse
- **Server:** `atom_warehouse` - TCP server managing CARBON, OXYGEN, HYDROGEN atoms
- **Client:** `atom_supplier` - Interactive TCP client for adding atoms
- **Key Features:**
  - TCP connection handling
  - Atom inventory management with overflow protection
  - Interactive menu system
  - Server response validation

### Q2: Molecule Delivery System
- **Server:** `molecule_supplier` - Multi-protocol server (TCP + UDP)
- **Client:** `molecule_requester` - Unified client supporting both protocols
- **Key Features:**
  - TCP for atom addition
  - UDP for molecule delivery (WATER, CARBON DIOXIDE, ALCOHOL, GLUCOSE)
  - Graceful shutdown with client notification
  - Hostname resolution support

### Q3: Bar Drinks with Admin Interface
- **Server:** `bar_drinks` - Enhanced warehouse with drink calculations
- **Key Features:**
  - All Q2 functionality
  - Admin commands via stdin (GEN SOFT DRINK, GEN VODKA, GEN CHAMPAGNE)
  - Advanced molecule formulas
  - Multiple client handling with select()

### Q4: Command Line Interface & Timeout
- **Server:** `bar_drinks_update` - Feature-complete server with CLI options
- **Key Features:**
  - Command-line argument parsing
  - Initial atom counts configuration
  - Timeout support with SIGALRM
  - Comprehensive error handling

### Q5: Unix Domain Sockets
- **Server:** `uds_warehouse` - Multi-transport server
- **Client:** `uds_requester` - Multi-transport client
- **Key Features:**
  - **Transport Layer Flexibility**: Concurrent support for network sockets (TCP/UDP) and Unix Domain Sockets (stream/datagram)
  - **Enhanced Socket Management**: Dynamic socket creation and cleanup with automatic socket file removal
  - **Bidirectional Communication Protocol**: Custom protocol implementation for both stream and datagram UDS
  - **Socket Pair Implementation**: Efficient data transfer between processes using socketpair() for internal IPC
  - **Non-Blocking I/O**: Implementation of non-blocking socket operations with select() for improved responsiveness
  - **Path-Based Addressing**: Support for abstract namespace UDS addressing alongside filesystem-based paths
  - **Transport Protocol Negotiation**: Clients can dynamically select between network and UDS transports
  - **Privilege Isolation**: Support for unprivileged operation using user-specific socket directories
  - **Comprehensive Socket Error Handling**: Enhanced error detection and recovery mechanisms

### Q6: Persistent Storage
- **Server:** `persistent_warehouse` - Production-ready server
- **Client:** `uds_requester` - Enhanced client (reused from Q5)
- **Key Features:**
  - **Memory-Mapped File Storage**: Implementation of `mmap()` for zero-copy access to persistent inventory data
  - **File Locking Mechanism**: Advanced implementation of `fcntl()` file locks to ensure atomic operations with advisory locking
  - **Data Integrity Protection**: Implementation of transaction-like operations for atomic updates to warehouse state
  - **Automatic Inventory Synchronization**: Immediate file synchronization using `msync()` with both MS_SYNC and MS_ASYNC modes
  - **Process Crash Recovery**: State preservation across server crashes and system reboots
  - **Journaling Mechanism**: Implementation of operation logging to prevent data corruption during unexpected terminations
  - **Memory-Mapped Metadata Management**: Efficient handling of inventory metadata alongside atom counts
  - **Multi-Process Coordination**: Support for concurrent access from multiple server instances with proper synchronization
  - **Signal Handler Integration**: Proper cleanup of memory-mapped resources in response to termination signals
  - **Magic Number Validation**: File format validation to prevent corruption when loading persisted data

## Compilation

### Build All Projects
```bash
make all
```

### Build Individual Questions
```bash
cd q1 && make
cd q2 && make
cd q3 && make
cd q4 && make
cd q5 && make
cd q6 && make
```

### Clean All
```bash
make clean
```

## Usage Examples

### Q1: Basic TCP Communication
```bash
# Terminal 1 - Start server
cd q1
./atom_warehouse 12345

# Terminal 2 - Start client
./atom_supplier 127.0.0.1 12345
```

### Q2: Multi-Protocol Server
```bash
# Terminal 1 - Start server (TCP + UDP)
cd q2
./molecule_supplier 12345 12346

# Terminal 2 - Start client
./molecule_requester 127.0.0.1 12345 12346
```

### Q3: Bar Drinks with Admin Commands
```bash
# Terminal 1 - Start enhanced server with drink calculations
cd q3
./bar_drinks 12345 12346

# Terminal 2 - Start client (same as Q2)
./molecule_requester 127.0.0.1 12345 12346

# In Terminal 1 (server), you can type admin commands:
# GEN SOFT DRINK
# GEN VODKA  
# GEN CHAMPAGNE
# shutdown
```

### Q4: Advanced Server with Options
```bash
# Start server with initial atoms and 60-second timeout
cd q4
./bar_drinks_update -T 12345 -U 12346 -c 1000 -o 2000 -H 3000 -t 60
```

### Q5: Unix Domain Sockets
```bash
# Terminal 1 - Start UDS server
cd q5
./uds_warehouse -s /tmp/stream.sock -d /tmp/datagram.sock

# Terminal 2 - Start UDS client
./uds_requester -f /tmp/stream.sock -d /tmp/datagram.sock
```

### Q6: Persistent Storage
```bash
# Terminal 1 - Start persistent server
cd q6
./persistent_warehouse -T 12345 -U 12346 -f warehouse.dat -c 1000 -o 1000 -H 1000

# Terminal 2 - Start client
./persistent_requester -h 127.0.0.1 -p 12345 -u 12346

# After server restart, inventory is preserved from warehouse.dat
```

## Supported Commands

### Client Commands (TCP/Stream)
- `ADD CARBON <amount>` - Add carbon atoms
- `ADD OXYGEN <amount>` - Add oxygen atoms  
- `ADD HYDROGEN <amount>` - Add hydrogen atoms

### Client Commands (UDP/Datagram)
- `DELIVER WATER <quantity>` - Request water molecules (2H + 1O)
- `DELIVER CARBON DIOXIDE <quantity>` - Request CO2 molecules (1C + 2O)
- `DELIVER ALCOHOL <quantity>` - Request alcohol molecules (2C + 6H + 1O)
- `DELIVER GLUCOSE <quantity>` - Request glucose molecules (6C + 12H + 6O)

### Admin Commands (Server stdin - Q3+)
- `GEN SOFT DRINK` - Calculate possible soft drinks (water + CO2 + alcohol)
- `GEN VODKA` - Calculate possible vodka (water + alcohol + glucose)
- `GEN CHAMPAGNE` - Calculate possible champagne (water + CO2 + glucose)
- `shutdown` - Graceful server shutdown

## Technical Implementation

### Key Technologies
- **Socket Programming:** TCP and UDP sockets for network communication
- **Unix Domain Sockets:** Stream and datagram modes for local IPC
- **Memory Mapping:** mmap() for zero-copy persistent storage
- **File Locking:** fcntl() for concurrent access control
- **Signal Handling:** SIGALRM for timeouts, signal masks for critical sections
- **Process Management:** select() for I/O multiplexing

### Advanced IPC Mechanisms (Q5-Q6)
- **UDS vs Network Sockets**: Implemented and compared both mechanisms, demonstrating UDS's performance advantages for local communication
- **Persistence Strategies**: Explored file-based persistence with both traditional I/O and memory mapping
- **Atomic Operations**: Implemented proper synchronization for multi-process access to shared resources
- **Error Recovery**: Developed robust error handling for various failure scenarios

### Error Handling
- Comprehensive input validation
- Overflow protection (max 10^18 atoms per type)
- Network error recovery
- File I/O error handling
- Graceful client disconnection

### Memory Management
- No memory leaks
- Proper resource cleanup
- Memory-mapped file synchronization

## Testing & Coverage

The project includes comprehensive test scripts and coverage analysis:

```bash
make coverage          # Generate coverage data
make coverage-report   # Generate coverage reports
```

## Notes

- All programs handle both IPv4 addresses and hostnames
- Maximum atom count per type: 10^18
- Default ports can be customized via command line
- UDS socket files are automatically cleaned up
- Persistent storage files use binary format with magic number validation
- Multiple transport layers can be used simultaneously
