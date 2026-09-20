# ==============================================================================
# DOCKERFILE - WHAT IS DOCKER AND WHY DO WE USE IT?
# ==============================================================================
# In cloud computing, "it works on my machine" is a common problem.
# Docker packages our code, Python runtime, and all libraries into a lightweight,
# self-contained "container image" that runs identically on your laptop, on AWS ECS,
# or anywhere else in the world.
# ==============================================================================

# 1. Base Image: Use official lightweight Python 3.12 Linux image
FROM python:3.12-slim

# 2. Set the working directory inside the container to /app
WORKDIR /app

# 3. Install OS-level dependencies:
# - libpq-dev & gcc: Required for compiling PostgreSQL database drivers (psycopg2)
# - curl: Used by the container healthcheck command
# - rm -rf /var/lib/apt/lists/*: Cleans up temporary apt cache to keep image size small
RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev curl gcc && rm -rf /var/lib/apt/lists/*

# 4. Copy requirements.txt first (Docker layer caching optimization)
# If our Python code changes but requirements.txt stays the same, Docker skips reinstalling packages!
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Security Hardening: Never run containers as 'root'!
# If an attacker compromises a root container, they could escape to the host.
# We create an unprivileged user named 'appuser' (UID 1001) to run our app safely.
RUN useradd -m -u 1001 appuser
USER appuser

# 6. Copy the rest of our application code and set ownership to 'appuser'
COPY --chown=appuser:appuser . .

# 7. Document that the container listens on network port 8000
EXPOSE 8000

# 8. Container Healthcheck:
# Docker regularly pings http://localhost:8000/health every 30s to verify the web server is responsive.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 9. Startup Command: Run the production Uvicorn ASGI server bound to all network interfaces (0.0.0.0)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
