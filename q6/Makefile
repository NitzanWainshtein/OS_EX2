CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

all: persistent_warehouse persistent_requester

persistent_warehouse: persistent_warehouse.c
	$(CC) $(CFLAGS) -o persistent_warehouse persistent_warehouse.c

persistent_requester: persistent_requester.c
	$(CC) $(CFLAGS) -o persistent_requester persistent_requester.c

coverage:
	gcov *.c

coverage-report:
	@echo "=== Q6 Code Coverage Report ===" > coverage_report_q6.txt
	@echo "Generated on: $$(date)" >> coverage_report_q6.txt
	@echo "" >> coverage_report_q6.txt
	@gcov *.c 2>&1 | grep "Lines executed" >> coverage_report_q6.txt 2>/dev/null || echo "No coverage data found - run programs first" >> coverage_report_q6.txt
	@echo "" >> coverage_report_q6.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q6.txt
	@ls *.gcov >> coverage_report_q6.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q6.txt
	@echo "" >> coverage_report_q6.txt
	@echo "=== Uncovered Lines (####) ===" >> coverage_report_q6.txt
	@grep "####" *.gcov >> coverage_report_q6.txt 2>/dev/null || echo "All lines covered!" >> coverage_report_q6.txt
	@echo "Coverage report saved to coverage_report_q6.txt"

clean:
	rm -f persistent_warehouse persistent_requester *.gcno *.gcda *.gcov *.sock

# Clean inventory files
clean-inventory:
	rm -f *.dat *.inv

# Test multiple processes
test-multi:
	@echo "Testing multiple processes..."
	./persistent_warehouse -T 12345 -U 12346 -f /tmp/test_inventory.dat &
	@echo "Server started. You can now run multiple clients:"
	@echo "./persistent_requester -h 127.0.0.1 -p 12345 -u 12346"