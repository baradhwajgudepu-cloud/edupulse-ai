import os

def search_text_in_files(directory, text):
    matches = []
    for root, dirs, files in os.walk(directory):
        if ".venv" in root or ".git" in root or "__pycache__" in root:
            continue
        for file in files:
            if file.endswith(('.py', '.env', '.example', '.json', '.md', '.txt', '.sh')):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                        for line_num, line in enumerate(f, 1):
                            if text in line:
                                matches.append((path, line_num, line.strip()))
                except Exception:
                    pass
    return matches

print("--- Searching for admin@edupulse.com ---")
for match in search_text_in_files("D:\\EDU_PULSE_AI\\backend", "admin@edupulse.com"):
    print(f"{match[0]}:{match[1]}: {match[2]}")

print("--- Searching for principal.d3b073 ---")
for match in search_text_in_files("D:\\EDU_PULSE_AI\\backend", "principal.d3b073"):
    print(f"{match[0]}:{match[1]}: {match[2]}")

print("--- Searching for suresh@school.edu ---")
for match in search_text_in_files("D:\\EDU_PULSE_AI\\backend", "suresh@school.edu"):
    print(f"{match[0]}:{match[1]}: {match[2]}")
