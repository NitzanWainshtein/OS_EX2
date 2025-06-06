CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

all: persistent_warehouse uds_requester

persistent_warehouse: persistent_warehouse.c
	$(CC) $(CFLAGS) -o persistent_warehouse persistent_warehouse.c

uds_requester: ../q5/uds_requester.c
	$(CC) $(CFLAGS) -o uds_requester ../q5/uds_requester.c

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
	rm -f persistent_warehouse uds_requester *.gcno *.gcda *.gcov *.sock *.dat

# Clean socket files
clean-sockets:
	rm -f /tmp/*.sock *.sock

.PHONY: all coverage coverage-report clean clean-sockets