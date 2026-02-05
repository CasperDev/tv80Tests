#!/bin/bash
set -e

# --- Kolory ANSI ---
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# --- Parametry ---
CMD="$1"
VIEW="$2"
UUT="src/tv80s.sv src/tv80_alu.sv src/tv80_core.sv src/tv80_mcode.sv src/tv80_reg.sv src/alu_add.sv"
INCPATH="tests"

# --- Zliczanie wyników ---
PASSED=0
FAILED=0
TOTAL=0

# --- Funkcja uruchamiająca pojedynczy test ---
run_test() {
    local test_dir="$1"
	local test_base_name="$(basename "$test_dir")"
    local tb_file="${test_dir}/${test_base_name}.sv"
	local out_dir="${test_dir}/out"
    local log_file="${out_dir}/${test_base_name}.log"
    local vvp_file="${out_dir}/${test_base_name}.vvp"
    local vcd_file="${out_dir}/${test_base_name}.vcd"
    local gtkw_file="${out_dir}/${test_base_name}.gtkw"

    mkdir -p "$out_dir"

    # --- Pobranie nazwy testu z pliku test.v ---
    local test_name

    # Szukaj localparam lub define
    if grep -q "module tb_" "$tb_file"; then
        test_name=$(grep "module tb_" "$tb_file" | head -n 1 | sed -E 's/(.*);.*/\1/')
    else
        test_name="$(basename "$test_dir")"
    fi
    [ -z "$test_name" ] && test_name="$(basename "$test_dir")"

# Tekst bazowy
    local label="Running test: ${test_name}"
    local total_width=60

    # Oblicz ile spacji potrzeba, by razem zajmowało 50 znaków
    local pad=$((total_width - ${#label}))
    ((pad < 0)) && pad=0
    local spaces=$(printf '%*s' "$pad")

    # Wypisz wyrównany tekst (bez nowej linii)
    printf "%s%s" "$label" "$spaces"
	
    # --- Kompilacja ---
    if ! iverilog -g2012 -I $INCPATH -o "$vvp_file" "$tb_file" $UUT 2> "$log_file"; then
        echo -e "\n❌ ${RED}Compile error in $test_name${RESET}"
        FAILED=$((FAILED + 1))
        TOTAL=$((TOTAL + 1))
		cat "$log_file"
        return
    fi

    # --- Symulacja ---
    if ! vvp "$vvp_file" +vcd="$vcd_file" > "$log_file"; then
        echo -e "\n❌ ${RED}Simulation crashed in $test_name${RESET}"
        FAILED=$((FAILED + 1))
        TOTAL=$((TOTAL + 1))
		cat "$log_file"
        return
    fi

	# --- Sprawdzenie logu ---
    if grep -q "FAIL" "$log_file"; then
        echo "❌ ${RED}FAILED${RESET}"
        FAILED=$((FAILED + 1))
		 # pokaż szczegóły błędu
    	grep '^- FAIL:' "$log_file" | sed "s/^/${RED}/; s/$/${RESET}/"
    else
        echo "✅ ${GREEN}PASSED${RESET}"
        PASSED=$((PASSED + 1))
    fi
	
    TOTAL=$((TOTAL + 1))

	# --- Otwórz GTKWave, jeśli proszono ---
    if [ "$VIEW" = "view" ]; then
        if [ -f "$vcd_file" ]; then
            echo "📈 Opening GTKWave for $test_name..."
            (cd "$out_dir" && nohup gtkwave --rcvar 'fontname_signals Monospace 13' --rcvar 'fontname_waves Monospace 13' "$test_base_name.vcd" "$test_base_name.gtkw" >/dev/null 2>&1 & disown)
		else
            echo "⚠️  VCD file not found: $vcd_file"
        fi
    fi
	
}
echo ""
echo "=============================================="

# --- Wybór testów na podstawie parametru ---
TESTS_DIR="tests"

if [ -n "$1" ]; then
    # Pozwól używać wzorców typu 03*, *inc_bc*, itp.
	echo "Filtering tests with pattern: $1"
    TEST_PATTERN="$1"
    TEST_DIRS=($(find "$TESTS_DIR" -mindepth 1 -maxdepth 1 -type d -name "$TEST_PATTERN" | sort))
else
    # Brak parametru → wszystkie testy
    TEST_DIRS=($(find "$TESTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort))
fi

# --- Uruchomienie testów ---
if [ ${#TEST_DIRS[@]} -eq 0 ]; then
    echo "No tests found matching pattern: $1"
    exit 1
fi

for dir in "${TEST_DIRS[@]}"; do
    run_test "$dir"
done

# --- Podsumowanie ---
echo "=============================================="
echo "🧾 ${YELLOW}Summary:${RESET}"
echo "   Total: $TOTAL"
echo "   ${GREEN}Passed: $PASSED${RESET}"
echo "   ${RED}Failed: $FAILED${RESET}"
echo "=============================================="

if [ $FAILED -eq 0 ]; then
    echo "🎉 ${GREEN}All tests passed!${RESET}"
else
    echo "❌ ${RED}Some tests failed.${RESET}"
    exit 1
fi
