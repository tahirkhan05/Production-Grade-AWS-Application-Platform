import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker

# ==============================================================================
# DATABASE CONNECTION CONFIGURATION
# ==============================================================================
# Why environment variables?
# In cloud applications, we NEVER hardcode database passwords or hostnames.
# When running on AWS ECS Fargate, AWS injects these variables directly into
# the container at startup from AWS Secrets Manager and Terraform environment configs.
# If running locally, it falls back to the default values provided as the 2nd argument.
# ==============================================================================

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgrespassword")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "appdb")

# PostgreSQL Connection String Format:
# postgresql://<username>:<password>@<host>:<port>/<database_name>
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# ==============================================================================
# SQLALCHEMY ENGINE & CONNECTION POOLING
# ==============================================================================
# The 'engine' is the core interface to the database.
# In production, opening and closing a new database connection for every web request
# is very slow and can crash the database.
#
# Connection Pooling solves this by keeping a pool of reusable connections open:
# - pool_size=10: Keep 10 persistent connections open and ready to handle queries instantly.
# - max_overflow=20: Under high traffic spikes, allow up to 20 extra temporary connections.
# - pool_recycle=1800: Refresh connections every 30 minutes (1800s) to avoid stale socket drops.
# - pool_pre_ping=True: Tests the connection with a quick 'ping' before using it, preventing
#   'server closed connection unexpectedly' errors if AWS RDS restarts or fails over.
# ==============================================================================
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_recycle=1800,
    pool_pre_ping=True
)

# SessionLocal is a factory that produces a new database transaction session when called
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class which our SQLAlchemy database tables (models.py) will inherit from
Base = declarative_base()


# ==============================================================================
# FASTAPI DEPENDENCY: DATABASE SESSION LIFECYCLE
# ==============================================================================
# This function is used in FastAPI route functions like: db: Session = Depends(get_db)
# 1. It opens a database session for the incoming HTTP request.
# 2. 'yield db' passes control to the endpoint to execute queries.
# 3. 'finally: db.close()' GUARANTEES the connection is returned to the pool
#    even if an unhandled error happens during the request. This prevents memory leaks.
# ==============================================================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ==============================================================================
# DATABASE HEALTH PROBE (Readiness Check)
# ==============================================================================
# Used by the '/ready' endpoint.
# AWS Application Load Balancers and Kubernetes use probes to verify if a container
# is ready to receive real user traffic. If the database is still booting up,
# this returns False, preventing users from seeing ugly database connection errors.
# ==============================================================================
def check_db_health():
    try:
        # Run a lightweight 'SELECT 1' query to test active network socket to PostgreSQL
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True, "Database connection successful"
    except Exception as e:
        return False, str(e)
