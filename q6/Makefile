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
	rm -f persistent_warehouse persistent_requester *.gcno *.gcda *.gcov *.sock *.dat

test-coverage: all
	@echo "Running comprehensive coverage tests..."
	# TCP tests
	./persistent_warehouse -T 50000 -f test.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1 & \
	PID=$$!; sleep 2; \
	echo "ADD CARBON 100" | nc localhost 50000; \
	echo "ADD OXYGEN 50" | nc localhost 50000; \
	kill $$PID 2>/dev/null; wait $$PID 2>/dev/null
	# UDP tests  
	./persistent_warehouse -U 50001 -f test2.dat -c 500 -o 500 -H 500 >/dev/null 2>&1 & \
	PID=$$!; sleep 2; \
	echo "DELIVER WATER 10" | nc -u localhost 50001; \
	kill $$PID 2>/dev/null; wait $$PID 2>/dev/null
	# Admin tests
	{ echo "GEN SOFT DRINK"; echo "shutdown"; } | ./persistent_warehouse -T 50002 -f test3.dat -c 1000 -o 1000 -H 1000 >/dev/null 2>&1

.PHONY: all coverage coverage-report clean test-coverage