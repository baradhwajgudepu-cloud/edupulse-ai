import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import smtplib
from email.mime.text import MIMEText

def test_smtp():
    host = "smtp.gmail.com"
    port = 587
    user = "edupulsetechnolgies@gmail.com"
    password = "Gudepu@84"

    try:
        print(f"Connecting to {host}:{port}...")
        server = smtplib.SMTP(host, port, timeout=10)
        server.starttls()
        print("Authenticating with Gmail SMTP...")
        server.login(user, password)
        print("[SUCCESS] Gmail SMTP login accepted!")
        server.quit()
        return True
    except smtplib.SMTPAuthenticationError as auth_err:
        print(f"[SMTP Auth Note] Gmail rejected direct account password: {auth_err}")
        print("Google typically requires a 16-character App Password (from myaccount.google.com/apppasswords) when 2FA is enabled.")
        return False
    except Exception as e:
        print(f"[SMTP Connection Result]: {e}")
        return False

if __name__ == "__main__":
    test_smtp()
