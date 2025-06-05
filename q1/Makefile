CC = gcc
CFLAGS = -Wall -Wextra -g --coverage

all: atom_warehouse atom_supplier

atom_warehouse: atom_warehouse.c
	$(CC) $(CFLAGS) -o atom_warehouse atom_warehouse.c

atom_supplier: atom_supplier.c
	$(CC) $(CFLAGS) -o atom_supplier atom_supplier.c

coverage:
	gcov *.c

coverage-report:
	@echo "=== Q1 Code Coverage Report ===" > coverage_report_q1.txt
	@echo "Generated on: $$(date)" >> coverage_report_q1.txt
	@echo "" >> coverage_report_q1.txt
	@gcov *.c 2>&1 | grep "Lines executed" >> coverage_report_q1.txt 2>/dev/null || echo "No coverage data found - run programs first" >> coverage_report_q1.txt
	@echo "" >> coverage_report_q1.txt
	@echo "Coverage files (.gcov) generated:" >> coverage_report_q1.txt
	@ls *.gcov >> coverage_report_q1.txt 2>/dev/null || echo "No .gcov files found" >> coverage_report_q1.txt
	@echo "" >> coverage_report_q1.txt
	@echo "=== Uncovered Lines (####) ===" >> coverage_report_q1.txt
	@grep "####" *.gcov >> coverage_report_q1.txt 2>/dev/null || echo "All lines covered!" >> coverage_report_q1.txt
	@echo "Coverage report saved to coverage_report_q1.txt"

clean:
	rm -f atom_warehouse atom_supplier *.gcno *.gcda *.gcov