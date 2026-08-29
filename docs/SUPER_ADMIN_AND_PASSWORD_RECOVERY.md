# EduPulse AI — Super Admin Provisioning & Password Recovery Operations Guide

## 1. Security Architecture & Principles

EduPulse AI implements defense-in-depth security standards across all identity, authentication, and password recovery workflows:

| Security Control | Implementation Details |
| :--- | :--- |
| **Password Hashing** | Argon2id (`argon2-cffi`) with cryptographically secure salt and parameters. |
| **Reset Token Generation** | `secrets.token_urlsafe(32)` providing 256 bits of cryptographic entropy. |
| **Token Storage** | SHA-256 hash (`hashlib.sha256(token.encode()).hexdigest()`) stored directly in `User.password_reset_hash`. Plaintext tokens are **never** persisted in the database. |
| **Account Enumeration Protection** | `POST /api/v1/auth/forgot-password` returns an identical generic response (`"If an account exists with this email address, password reset instructions have been sent."`) regardless of whether the email exists. |
| **Single-Use Enforcement** | `User.password_reset_hash` and `User.password_reset_expires_at` are cleared immediately upon successful password reset; reuse attempts are rejected (HTTP 400). |
| **Expiration Enforcement** | Tokens expire after a configurable window (`PASSWORD_RESET_TOKEN_EXPIRE_MINUTES`, default 30 minutes). |
| **Session Revocation** | All active refresh tokens and user sessions are automatically revoked upon successful password reset. |
| **Account Unlock** | Authentication-related lockouts (`UserStatus.LOCKED`, `failed_login_attempts`) are automatically cleared and reset to `UserStatus.ACTIVE` upon successful password recovery. |
| **Rate Limiting** | Sliding-window rate limits per IP (10 req/15m) and per email (5 req/15m) protect against reset spam and brute-force attacks. |
| **Startup Safety** | Automatic system bootstrapping during server startup is strictly **disabled** (`ENABLE_BOOTSTRAP=false`). |

---

## 2. Super Admin Bootstrap & Update Procedures

The Super Admin bootstrap script is an idempotent operations tool for provisioning and updating platform administrators.

**Script Location:** `backend/scripts/bootstrap_super_admin.py`

### Environment Variables

| Variable | Description | Default |
| :--- | :--- | :--- |
| `SUPER_ADMIN_EMAIL` | Target Super Admin email address | *Must be provided at runtime* |
| `SUPER_ADMIN_INITIAL_PASSWORD` | Strong initial or updated password | *Must be provided at runtime* |
| `SUPER_ADMIN_FIRST_NAME` | Super Admin first name | `Super` |
| `SUPER_ADMIN_LAST_NAME` | Super Admin last name | `Admin` |
| `DATABASE_URL` | PostgreSQL connection string | *Injected from environment/Secret Manager* |

> [!CAUTION]
> Never commit actual passwords or connection strings to source control. In production (Cloud Run), inject these values via Google Secret Manager.

### CLI Usage & Flags

```bash
# 1. Dry-run simulation (verifies configuration without writing to DB)
SUPER_ADMIN_EMAIL="edupulsetechnologies@gmail.com" \
SUPER_ADMIN_INITIAL_PASSWORD="SecurePassword123!" \
python backend/scripts/bootstrap_super_admin.py --dry-run

# 2. Provision Super Admin if missing (creates account with SUPER_ADMIN role & is_superuser=True)
SUPER_ADMIN_EMAIL="edupulsetechnologies@gmail.com" \
SUPER_ADMIN_INITIAL_PASSWORD="SecurePassword123!" \
python backend/scripts/bootstrap_super_admin.py

# 3. Ensure Super Admin account and role exist without modifying existing password
SUPER_ADMIN_EMAIL="edupulsetechnologies@gmail.com" \
python backend/scripts/bootstrap_super_admin.py --ensure

# 4. Explicitly update/reset the Super Admin password
SUPER_ADMIN_EMAIL="edupulsetechnologies@gmail.com" \
SUPER_ADMIN_INITIAL_PASSWORD="NewSecurePassword456@" \
python backend/scripts/bootstrap_super_admin.py --reset-password
```

---

## 3. Password Recovery API Endpoints

### 1. Request Password Reset (Forgot Password)

- **Method:** `POST`
- **Path:** `/api/v1/auth/forgot-password`
- **Access:** Public (Rate-limited)
- **Request Body:**
  ```json
  {
    "email": "user@example.com"
  }
  ```
- **Response (HTTP 200 OK):**
  ```json
  {
    "success": true,
    "message": "If an account exists with this email address, password reset instructions have been sent.",
    "data": null
  }
  ```

### 2. Confirm Password Reset

- **Method:** `POST`
- **Path:** `/api/v1/auth/reset-password`
- **Access:** Public
- **Request Body:**
  ```json
  {
    "token": "raw_urlsafe_token_from_email",
    "new_password": "NewSecurePassword123!",
    "confirm_password": "NewSecurePassword123!"
  }
  ```
- **Response (HTTP 200 OK):**
  ```json
  {
    "success": true,
    "message": "Password has been reset successfully. You may now sign in with your new password.",
    "data": null
  }
  ```

---

## 4. SMTP Email Delivery Configuration

In production, configure SMTP credentials in Google Secret Manager or Cloud Run environment:

```ini
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USERNAME="edupulsetechnologies@gmail.com"
SMTP_PASSWORD="<app-specific-password>"
SMTP_FROM_EMAIL="noreply@edupulse.com"
SMTP_FROM_NAME="EduPulse AI"
SMTP_USE_TLS=true
FRONTEND_BASE_URL="https://edupulse-ai-17221.web.app"
PASSWORD_RESET_TOKEN_EXPIRE_MINUTES=30
```

When `SMTP_HOST` is unconfigured in development/DEBUG mode, the backend simulates dispatch and outputs security-safe logs without exposing tokens or sensitive parameters.

---

## 5. Flutter Admin Portal Architecture

The Admin Portal frontend integrates password recovery into the clean architecture layers:

1. **Login Screen (`LoginScreen`):**
   - Contains a prominent "Forgot Password?" action button navigating to `/forgot-password`.
2. **Forgot Password Screen (`ForgotPasswordScreen`):**
   - Validates email format.
   - Dispatches reset request through `AuthRepository.requestPasswordReset`.
   - On completion, transitions to the generic confirmation state.
3. **Reset Password Screen (`ResetPasswordScreen`):**
   - Reads the token directly from the URI query parameter (`/reset-password?token=...`).
   - Displays password visibility toggles and real-time complexity validation (8+ chars, uppercase, lowercase, number, special character).
   - Validates password match.
   - Dispatches reset via `ResetPasswordUseCase`.
   - On success, directs user back to sign in.
4. **Public Routes:**
   - Both `/forgot-password` and `/reset-password` are registered in `AppRoutes` and bypass redirect guards in `app_router.dart`.

---

## 6. Operational Troubleshooting & Verification Checklist

- [x] Sourced `User.password_reset_hash` and `User.password_reset_expires_at` without duplicate tables.
- [x] Removed obsolete script `backend/app/reset_principal_uat_password.py`.
- [x] Super Admin bootstrap CLI supports `--ensure`, `--reset-password`, `--dry-run`, `--first-name`, and `--last-name`.
- [x] `POST /api/v1/auth/forgot-password` prevents user enumeration.
- [x] Sliding-window rate limiting protects against reset spam.
- [x] Tokens expire after 30 minutes and are single-use.
- [x] Password changes unlock locked accounts and revoke active refresh tokens.
- [x] Backend tests (`test_auth_password_reset.py`, `test_bootstrap_super_admin.py`) pass 15/15.
- [x] Flutter widget tests (`forgot_password_feature_test.dart`) pass 6/6.
