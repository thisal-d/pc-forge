#!/usr/bin/env python3
"""PCForge Database Initializer & Migration Utility.
Applies db/schema.sql and db/seed.sql to PostgreSQL (Neon Serverless).
Supports idempotent checking, schema reset, seeding, and verification.
"""

import os
import sys
import argparse
from pathlib import Path

# Load environment variables if python-dotenv is available
try:
    from dotenv import load_dotenv
    root_dir = Path(__file__).resolve().parent.parent
    load_dotenv(root_dir / ".env")
    load_dotenv(root_dir / "backend" / ".env")
except ImportError:
    pass

import psycopg2

# Ensure UTF-8 output on Windows consoles
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def get_connection_string(cli_arg: str = None) -> str:
    if cli_arg:
        return cli_arg
    conn = os.getenv("DATABASE_URL") or os.getenv("ConnectionStrings__DefaultConnection")
    if not conn:
        print("[ERROR] No connection string found! Please set DATABASE_URL in .env or pass --connection-string.")
        sys.exit(1)
    return conn


def mask_url(url: str) -> str:
    if "@" in url and "://" in url:
        prefix, rest = url.split("://", 1)
        creds, host_part = rest.split("@", 1)
        if ":" in creds:
            user = creds.split(":", 1)[0]
            return f"{prefix}://{user}:****@{host_part}"
    return url


def get_public_tables(cur):
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    """)
    return [r[0] for r in cur.fetchall()]


def print_table_status(cur, db_name: str):
    tables = get_public_tables(cur)
    print(f"\n[INFO] Found {len(tables)} tables in '{db_name}':")
    for idx, tbl in enumerate(tables, 1):
        try:
            cur.execute(f"SELECT COUNT(*) FROM \"{tbl}\";")
            count = cur.fetchone()[0]
            print(f"   {idx:2d}. {tbl:<25} ({count} rows)")
        except Exception:
            print(f"   {idx:2d}. {tbl:<25} (unable to count)")


def reset_public_schema(cur):
    print("\n[RESET] Dropping public schema and recreating clean schema...")
    cur.execute("DROP SCHEMA public CASCADE;")
    cur.execute("CREATE SCHEMA public;")
    cur.execute("GRANT ALL ON SCHEMA public TO PUBLIC;")
    print("[OK] Public schema reset successfully.")


def setup_database(conn_str: str, seed: bool = True, reset: bool = False, status_only: bool = False):
    db_dir = Path(__file__).resolve().parent
    schema_file = db_dir / "schema.sql"
    seed_file = db_dir / "seed.sql"

    print("==================================================================")
    print(">> PCForge Database Setup & Migration Utility")
    print("==================================================================")
    print(f"Target Database: {mask_url(conn_str)}")

    print("\n[1/4] Connecting to PostgreSQL...")
    conn = psycopg2.connect(conn_str)
    conn.autocommit = True
    cur = conn.cursor()

    cur.execute("SELECT current_database(), version();")
    db_name, version = cur.fetchone()
    print(f"[OK] Connected to database: '{db_name}'")
    print(f"     Server version: {version.split(',')[0]}")

    if status_only:
        print_table_status(cur, db_name)
        cur.close()
        conn.close()
        return

    existing_tables = get_public_tables(cur)

    if existing_tables and not reset:
        print(f"\n[NOTE] Database '{db_name}' already contains {len(existing_tables)} tables.")
        print_table_status(cur, db_name)
        print("\n[INFO] Tables are already initialized! To completely wipe and rebuild, re-run with: --reset")
        cur.close()
        conn.close()
        return

    if reset:
        reset_public_schema(cur)

    print(f"\n[2/4] Executing Schema ({schema_file.name})...")
    schema_sql = schema_file.read_text(encoding="utf-8")
    cur.execute(schema_sql)
    print("[OK] Schema applied successfully (Tables, Views, Indexes created).")

    if seed:
        print(f"\n[3/4] Executing Seed Data ({seed_file.name})...")
        seed_sql = seed_file.read_text(encoding="utf-8")
        cur.execute(seed_sql)
        print("[OK] Seed data inserted successfully (Categories, Products, Users, Builds).")
    else:
        print("\n[3/4] Skipping seed data (--no-seed passed).")

    print("\n[4/4] Verifying database tables...")
    print_table_status(cur, db_name)

    cur.close()
    conn.close()
    print("\n[SUCCESS] Database configuration completed successfully!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Configure PCForge database on Neon PostgreSQL")
    parser.add_argument("--connection-string", "-c", help="PostgreSQL connection string URL", default=None)
    parser.add_argument("--reset", action="store_true", help="Drop and rebuild all tables from scratch")
    parser.add_argument("--no-seed", action="store_true", help="Apply schema only without seeding data")
    parser.add_argument("--status", action="store_true", help="Only check and display existing tables and row counts")
    args = parser.parse_args()

    conn_url = get_connection_string(args.connection_string)
    setup_database(conn_url, seed=not args.no_seed, reset=args.reset, status_only=args.status)
