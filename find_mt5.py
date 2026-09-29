import os

common_dirs = [
    r"C:\Program Files",
    r"C:\Program Files (x86)",
    os.environ.get("LOCALAPPDATA", ""),
    os.environ.get("APPDATA", ""),
    r"C:\Users\Booth"
]

found = []

for base in common_dirs:
    if not base or not os.path.exists(base):
        continue
    # Search top 4 levels
    for root, dirs, files in os.walk(base):
        depth = root[len(base):].count(os.sep)
        if depth > 4:
            dirs.clear() # don't recurse deeper
            continue
        for f in files:
            if f.lower() in ["terminal64.exe", "metaeditor64.exe"]:
                full_path = os.path.join(root, f)
                found.append(full_path)

print("SEARCH RESULTS:")
if found:
    for item in set(found):
        print(f"FOUND: {item}")
else:
    print("NO_MT5_EXECUTABLES_FOUND")
