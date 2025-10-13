#!/bin/bash
set -e  # zakończ, jeśli którykolwiek krok zwróci błąd

# --- Parametr opcjonalny (np. fuse.sh test1) ---
CMD="$1"

# --- Pliki źródłowe ---
UUT="../src/tv80s.sv ../src/tv80_alu.sv ../src/tv80_core.sv ../src/tv80_mcode.sv ../src/tv80_reg.sv"
TESTFILE="fuse_tb"

# --- Kompilacja ---
echo "Compiling $TESTFILE.sv ..."
if ! iverilog -g2012 -o "${TESTFILE}.vvp" "${TESTFILE}.sv" ${UUT}; then
    echo "❌ Compile error!"
    exit 1
fi

# --- Symulacja ---
echo "Running simulation..."
if ! vvp "${TESTFILE}.vvp" > fuse.log; then
    echo "❌ Simulation failed!"
    exit 1
fi

echo "✅ Done. Output written to fuse.log"
