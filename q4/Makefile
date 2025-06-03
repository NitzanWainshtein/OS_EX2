CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

all: bar_drinks_update molecule_requester_update

bar_drinks_update: bar_drinks_update.c
	$(CC) $(CFLAGS) -o bar_drinks_update bar_drinks_update.c

molecule_requester_update: molecule_requester_update.c
	$(CC) $(CFLAGS) -o molecule_requester_update molecule_requester_update.c

coverage:
	gcov *.c

coverage-report:
	@echo "=== Q4 Code Coverage Report ===" > coverage_report_q4.txt
	@echo "Generated on: $$(date)" >> coverage_report_q4.txt
	@echo "" >> coverage_report_q4.txt
	@gcov *.c 2>&1 | grep "Lines executed" >> coverage_report_q4.txt 2>/dev/null || echo "No coverage data found" >> coverage_report_q4.txt
	@echo "" >> coverage_report_q4.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q4.txt
	@ls *.gcov >> coverage_report_q4.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q4.txt
	@echo "Coverage report saved to coverage_report_q4.txt"

clean:
	rm -f bar_drinks_update molecule_requester_update *.gcno *.gcda *.gcov