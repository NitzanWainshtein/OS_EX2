CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

Q2_DIR = ../q2
CLIENT_SRC = $(Q2_DIR)/molecule_requester.c

all: bar_drinks molecule_requester

bar_drinks: bar_drinks.c
	$(CC) $(CFLAGS) -o bar_drinks bar_drinks.c

molecule_requester: $(CLIENT_SRC)
	$(CC) $(CFLAGS) -o molecule_requester $(CLIENT_SRC)

coverage:
	gcov bar_drinks.c

coverage-report:
	@echo "=== Q3 Code Coverage Report ===" > coverage_report_q3.txt
	@echo "Generated on: $$(date)" >> coverage_report_q3.txt
	@echo "" >> coverage_report_q3.txt
	@gcov bar_drinks.c 2>&1 | grep "Lines executed" >> coverage_report_q3.txt 2>/dev/null || echo "No coverage data found - run programs first" >> coverage_report_q3.txt
	@echo "" >> coverage_report_q3.txt
	@echo "Note: molecule_requester built from Q2 source" >> coverage_report_q3.txt
	@echo "" >> coverage_report_q3.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q3.txt
	@ls *.gcov >> coverage_report_q3.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q3.txt
	@echo "" >> coverage_report_q3.txt
	@echo "=== Uncovered Lines (####) ===" >> coverage_report_q3.txt
	@grep "####" *.gcov >> coverage_report_q3.txt 2>/dev/null || echo "All lines covered!" >> coverage_report_q3.txt
	@echo "Coverage report saved to coverage_report_q3.txt"

clean:
	rm -f bar_drinks molecule_requester *.gcno *.gcda *.gcov