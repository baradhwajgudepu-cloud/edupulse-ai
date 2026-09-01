with open("D:\\EDU_PULSE_AI\\backend\\qa_reports\\release_test_harness.py", "r", encoding="utf-8") as f:
    for line_num, line in enumerate(f, 1):
        if "payload" in line or "login" in line or "password" in line or "email" in line:
            if "@" in line or "Admin" in line or "Pass" in line:
                print(f"{line_num}: {line.strip()}")
