CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

all: uds_warehouse uds_requester

uds_warehouse: uds_warehouse.c
	$(CC) $(CFLAGS) -o uds_warehouse uds_warehouse.c

uds_requester: uds_requester.c
	$(CC) $(CFLAGS) -o uds_requester uds_requester.c

coverage:
	gcov *.c

coverage-report:
	@echo "=== Q5 Code Coverage Report ===" > coverage_report_q5.txt
	@echo "Generated on: $$(date)" >> coverage_report_q5.txt
	@echo "" >> coverage_report_q5.txt
	@gcov *.c 2>&1 | grep "Lines executed" >> coverage_report_q5.txt 2>/dev/null || echo "No coverage data found - run programs first" >> coverage_report_q5.txt
	@echo "" >> coverage_report_q5.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q5.txt
	@ls *.gcov >> coverage_report_q5.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q5.txt
	@echo "" >> coverage_report_q5.txt
	@echo "=== Uncovered Lines (####) ===" >> coverage_report_q5.txt
	@grep "####" *.gcov >> coverage_report_q5.txt 2>/dev/null || echo "All lines covered!" >> coverage_report_q5.txt
	@echo "Coverage report saved to coverage_report_q5.txt"

clean:
	rm -f uds_warehouse uds_requester *.gcno *.gcda *.gcov *.sock

# Clean socket files
clean-sockets:
	rm -f /tmp/*.sock *.sock