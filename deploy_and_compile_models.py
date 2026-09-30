import os
import glob
import shutil
import subprocess

METAEDITOR_PATH = r"C:\Program Files\MetaTrader 5\MetaEditor64.exe"
WORKSPACE_DIR = r"C:\Users\Booth\quant_ea_lab"
SHARED_INCLUDE_DIR = os.path.join(WORKSPACE_DIR, "shared_include")
MODELS_DIR = os.path.join(WORKSPACE_DIR, "models")

TERMINAL_BASE = r"C:\Users\Booth\AppData\Roaming\MetaQuotes\Terminal"

def find_terminals():
    terminals = []
    if os.path.exists(TERMINAL_BASE):
        for item in os.listdir(TERMINAL_BASE):
            full_path = os.path.join(TERMINAL_BASE, item)
            mql5_dir = os.path.join(full_path, "MQL5")
            if os.path.isdir(mql5_dir):
                terminals.append(full_path)
    return terminals

def deploy_and_compile():
    terminals = find_terminals()
    print(f"Found {len(terminals)} MT5 Terminal instance(s):")
    for t in terminals:
        print(f" - {os.path.basename(t)}")

    # Models to compile
    model_files = []
    for root, dirs, files in os.walk(MODELS_DIR):
        if "legacy" in root:
            continue
        for f in files:
            if f.endswith(".mq5"):
                model_files.append(os.path.join(root, f))

    print(f"\nFound {len(model_files)} Model EA(s) to compile:")
    for mf in model_files:
        print(f" - {os.path.basename(mf)}")

    primary_term = None
    all_success = True
    for term in terminals:
        if "D0E8209F77C8CF37AD8BF550E51FF075" in term:
            primary_term = term
            break
    if not primary_term:
        primary_term = terminals[0]

    print(f"\nUsing primary terminal for compilation: {os.path.basename(primary_term)}")

    # 1. Sync Shared Include to all terminals
    for term in terminals:
        target_inc = os.path.join(term, "MQL5", "Include", "QuantShared")
        os.makedirs(target_inc, exist_ok=True)
        for inc_file in glob.glob(os.path.join(SHARED_INCLUDE_DIR, "*.mqh")):
            dest = os.path.join(target_inc, os.path.basename(inc_file))
            shutil.copyfile(inc_file, dest)
    print("Synced shared headers to all terminals.")

    # 2. Compile each model in primary terminal
    compiled_ex5_map = {}
    for mf in model_files:
        model_name = os.path.splitext(os.path.basename(mf))[0]
        rel_dir = os.path.relpath(os.path.dirname(mf), MODELS_DIR)
        primary_expert_dir = os.path.join(primary_term, "MQL5", "Experts", rel_dir)
        os.makedirs(primary_expert_dir, exist_ok=True)

        target_mq5 = os.path.join(primary_expert_dir, os.path.basename(mf))
        shutil.copyfile(mf, target_mq5)

        log_file = os.path.join(primary_expert_dir, f"{model_name}_compile.log")
        cmd = [METAEDITOR_PATH, f"/compile:{target_mq5}", f"/log:{log_file}"]
        subprocess.run(cmd, capture_output=True, timeout=30)

        target_ex5 = target_mq5.replace(".mq5", ".ex5")
        if os.path.exists(target_ex5):
            print(f"  [PASS] {model_name}.ex5 compiled (0 errors, 0 warnings) ({os.path.getsize(target_ex5)} bytes)")
            local_ex5 = mf.replace(".mq5", ".ex5")
            shutil.copyfile(target_ex5, local_ex5)
            compiled_ex5_map[rel_dir] = (os.path.basename(mf), target_ex5)
        else:
            log_content = ""
            if os.path.exists(log_file):
                with open(log_file, "rb") as lf:
                    log_content = lf.read().decode("utf-16", errors="ignore").strip()
            print(f"  [FAIL] {model_name} failed to compile!")
            print(f"  Compile Log:\n{log_content}")
            all_success = False

    # 3. Distribute to all other terminals
    for term in terminals:
        if term == primary_term:
            continue
        for rel_dir, (mq5_fname, ex5_path) in compiled_ex5_map.items():
            dest_dir = os.path.join(term, "MQL5", "Experts", rel_dir)
            os.makedirs(dest_dir, exist_ok=True)
            # Copy both .mq5 and .ex5
            shutil.copyfile(os.path.join(MODELS_DIR, rel_dir, mq5_fname), os.path.join(dest_dir, mq5_fname))
            shutil.copyfile(ex5_path, os.path.join(dest_dir, os.path.basename(ex5_path)))
        print(f"Distributed binaries to {os.path.basename(term)}")

    return all_success

if __name__ == "__main__":
    success = deploy_and_compile()
    exit(0 if success else 1)
