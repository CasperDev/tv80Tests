#!/bin/bash
set -e  # zakończ, jeśli którykolwiek krok zwróci błąd

# --- Parametr opcjonalny (np. fuse.sh test1) ---
TESTDEF="$1"
if [ -n "$TESTDEF" ]; then
	echo "Running specific test: $TESTDEF"
else 
	echo "Running all tests"
	TESTDEF="TEST_ALL"
fi
# --- Pliki źródłowe ---
UUT="../src/tv80s.sv ../src/tv80_alu.sv ../src/tv80_core.sv ../src/tv80_mcode.sv ../src/tv80_reg.sv"
TESTFILE="fuse_tb"

# --- Kompilacja ---
echo "Compiling $TESTFILE.sv ..."
if ! iverilog -D${TESTDEF} -g2012 -o "${TESTFILE}.vvp" "${TESTFILE}.sv" ${UUT}; then
    echo "❌ Compile error!"
    exit 1
fi

# --- Symulacja ---
echo "Running simulation..."
if ! vvp "${TESTFILE}.vvp" > "${TESTFILE}.log"; then
    echo "❌ Simulation failed!"
    exit 1
fi

# --- Kolory ANSI ---
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

PASS_COUNT=0
FAIL_COUNT=0

while IFS= read -r line; do
     if [[ "$line" =~ ^Test ]]; then
         if [[ "$line" =~ PASS ]]; then
             line="${line//PASS/$(printf '\033[1;32mPASS\033[0m')}"
             PASS_COUNT=$((PASS_COUNT + 1))
         elif [[ "$line" =~ FAIL ]]; then
             line="${line//FAIL/$(printf '\033[1;31mFAIL\033[0m')}"
             FAIL_COUNT=$((FAIL_COUNT + 1))
         fi
		echo $line
     fi
     if [[ "$line" =~ "- FAIL" ]]; then
         if [[ "$line" =~ PASS ]]; then
             line="${line//PASS/$(printf '\033[1;32mPASS\033[0m')}"
         elif [[ "$line" =~ FAIL ]]; then
             line="${line//FAIL/$(printf '\033[1;31mFAIL\033[0m')}"
         fi
		echo $line
     fi
done < "${TESTFILE}.log"

TOTAL=$((PASS_COUNT + FAIL_COUNT))

echo "------------------------------"
if (( TOTAL > 0 )); then
    echo -e "  Total $TOTAL tests:"
    echo -e "  ✅  \033[1;32m$PASS_COUNT PASS\033[0m"
    echo -e "  ❌  \033[1;31m$FAIL_COUNT FAIL\033[0m"
else
    echo "  No tests detected."
fi
echo "=============================="

