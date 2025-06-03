CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200112L --coverage

all: molecule_supplier molecule_requester

molecule_supplier: molecule_supplier.c
	$(CC) $(CFLAGS) -o molecule_supplier molecule_supplier.c

molecule_requester: molecule_requester.c
	$(CC) $(CFLAGS) -o molecule_requester molecule_requester.c

coverage:
	gcov *.c

coverage-report:
	@echo "=== Q2 Code Coverage Report ===" > coverage_report_q2.txt
	@echo "Generated on: $(date)" >> coverage_report_q2.txt
	@echo "" >> coverage_report_q2.txt
	@gcov *.c 2>&1 | grep "Lines executed" >> coverage_report_q2.txt 2>/dev/null || echo "No coverage data found - run programs first" >> coverage_report_q2.txt
	@echo "" >> coverage_report_q2.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q2.txt
	@ls *.gcov >> coverage_report_q2.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q2.txt
	@echo "Coverage report saved to coverage_report_q2.txt"

clean:
	rm -f molecule_supplier molecule_requester *.gcno *.gcda *.gcov