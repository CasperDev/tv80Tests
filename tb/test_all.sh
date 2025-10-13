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

echo "✅ Done. Output written to ${TESTFILE}.log"
