from pathlib import Path
import re

setup_lines = Path("tdata/setup.txt").read_text().strip().splitlines()
assert_text = Path("tdata/assert.txt").read_text()
template = Path("tdata/template.sv").read_text()
out_dir = Path("gentests")
out_dir.mkdir(exist_ok=True)

# --------------------------------------------
# Parsowanie SETUP
# --------------------------------------------
def parse_setup(lines):
    tests = {}
    i = 0
    while i < len(lines):
        name = lines[i].strip()
        regs16_values = lines[i + 1].strip().split()
        regs16_values = regs16_values[:-1]  # odrzucamy ostatni element (MEMPTR)
        regs16 = "_".join(regs16_values)
        regs8 = lines[i + 2].strip()
        mem = []
        i += 3
        while i < len(lines) and lines[i].strip() != "-1":
            mem.append(lines[i].strip())
            i += 1
        tests[name] = {
            "regs16": regs16,
            "regs8": regs8,
            "mem": mem
        }
        i += 2
    return tests

# --------------------------------------------
# Parsowanie ASSERT (blokami)
# --------------------------------------------
def parse_assert(text):
    tests = {}
    blocks = [b.strip() for b in text.strip().split("\n\n") if b.strip()]
    for block in blocks:
        lines = [ln for ln in block.splitlines() if ln.strip()]
        if not lines:
            continue

        name = lines[0].strip()
        # pomijamy linie zaczynające się od spacji
        core = [ln for ln in lines[1:] if not ln.startswith(" ")]
        if len(core) < 2:
            print(f"[!] Niekompletny blok assert dla testu {name}")
            continue

        regs16_values = core[0].strip().split()
        regs16_values = regs16_values[:-1]  # odrzucamy ostatni element (MEMPTR)
        regs16 = "_".join(regs16_values)
        regs8_line = core[1].strip().split()
        mem = core[2:]
        tests[name] = {
            "regs16": regs16,
            "regs8": regs8_line[:6],  # I, R, IFF1, IFF2, IM, HALT
            "cycles": regs8_line[6],
            "mem": mem
        }
    return tests

# --------------------------------------------
# Pomocnicze funkcje
# --------------------------------------------
def make_mem_init(mem_lines):
    code = []
    for line in mem_lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = int(parts[0], 16)
        for val in parts[1:]:
            if val == "-1":
                break
            code.append(f"SETMEM(16'h{addr:04x}, 8'h{val});")
            addr += 1
    return "\n        ".join(code)

# --------------------------------------------
# Pomocnicze funkcje
# --------------------------------------------
def make_assert_mem(mem_lines):
    code = []
    for line in mem_lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        addr = int(parts[0], 16)
        for val in parts[1:]:
            if val == "-1":
                break
            code.append(f"ASSERTMEM(16'h{addr:04x}, 8'h{val});")
            addr += 1
    return "\n        ".join(code)

setup_tests = parse_setup(setup_lines)
assert_tests = parse_assert(assert_text)

for name, s in setup_tests.items():
    if name not in assert_tests:
        print(f"[!] Brak assertu dla testu {name}")
        continue
    a = assert_tests[name]

    print(f"[+] Generuję test: {name}")
    #print(s)
    #print(a)
    
    code = template
    code = code.replace("TESTNAME", name)
    code = code.replace("SETUP_REGS", f"192'h{s['regs16']}")
    code = code.replace("SETUP_IREG", f"8'h{s['regs8'].split()[0]}")
    code = code.replace("SETUP_RREG", f"8'h{s['regs8'].split()[1]}")
    code = code.replace("SETUP_IFFS", f"2'b{s['regs8'].split()[3]}{s['regs8'].split()[2]}")
    code = code.replace("SETUP_HALT", f"1'b{s['regs8'].split()[5]}")
    code = code.replace("MEM_INIT", make_mem_init(s["mem"]))

    code = code.replace("ASSERT_REGS", f"192'h{a['regs16'].replace(' ', '_')}")
    code = code.replace("ASSERT_IREG", f"8'h{a['regs8'][0]}")
    code = code.replace("ASSERT_RREG", f"8'h{a['regs8'][1]}")
    code = code.replace("ASSERT_MODE", f"2'b{a['regs8'][3]}{a['regs8'][2]}")
    code = code.replace("ASSERT_HALT", f"1'b{a['regs8'][5]}")
    
    code = code.replace("RUNCLOCKS", f"{a['cycles']}")
    code = code.replace("ASSERT_MEM", make_assert_mem(a["mem"]))

    test_out_dir = Path.joinpath(out_dir,name)
    test_out_dir.mkdir(exist_ok=True)
    out_file = test_out_dir / f"{name}.sv"
    out_file.write_text(code)


print("✅ Gotowe.")
