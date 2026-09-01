import os

def search_text_in_files(directory, text):
    matches = []
    for root, dirs, files in os.walk(directory):
        if ".venv" in root or ".git" in root or "__pycache__" in root or ".dart_tool" in root or "build" in root:
            continue
        for file in files:
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    for line_num, line in enumerate(f, 1):
                        if text in line:
                            matches.append((path, line_num, line.strip()))
            except Exception:
                pass
    return matches

print("--- Searching for tenant ID in EDU_PULSE_AI ---")
for match in search_text_in_files("D:\\EDU_PULSE_AI", "d09b9362-3dc8-422d-a441-160735fcea96"):
    print(f"{match[0]}:{match[1]}: {match[2]}")
