# System-wide Core Constants

# Authentication constants
ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
ALGORITHM: str = "HS256"

# Multi-tenancy
DEFAULT_TENANT_ID: str = "00000000-0000-0000-0000-000000000000"

# Pagination defaults
DEFAULT_PAGE_SIZE: int = 20
MAX_PAGE_SIZE: int = 100
