FROM python:3.14-slim

WORKDIR /app

# Install system build dependencies for python packages (like cryptography / cffi)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source files
COPY app /app/app
COPY alembic /app/alembic
COPY alembic.ini /app/alembic.ini

# Create non-root system user and apply ownership permissions
RUN groupadd -r edupulse && useradd -r -g edupulse edupulse \
    && chown -R edupulse:edupulse /app

# Run as non-root user
USER edupulse

# Expose default HTTP port (Cloud Run will override using PORT env var)
EXPOSE 8080

# Execute server binding to 0.0.0.0 and dynamic Cloud Run PORT
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
