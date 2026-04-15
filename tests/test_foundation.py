"""
Week 1 smoke tests — all 5 must pass before Week 2 begins.
Target: Validate Infrastructure, Schema, and Security Posture.
"""

import os
import re
import subprocess
from pathlib import Path
import pytest
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from sqlalchemy import create_engine, text

@pytest.fixture(scope="session")
def engine():
    """SQLAlchemy engine via Key Vault — using the DefaultAzureCredential pattern."""
    # 1. Resolve Key Vault URI (Check Env first, fallback to Terraform)
    kv_uri = os.environ.get("KEY_VAULT_URI")
    if not kv_uri:
        kv_uri = subprocess.run(
            ["terraform", "output", "-raw", "key_vault_uri"],
            cwd="infra/terraform",
            capture_output=True,
            text=True
        ).stdout.strip()
    
    # 2. Fetch connection string from Vault
    cred = DefaultAzureCredential()
    client = SecretClient(vault_url=kv_uri, credential=cred)
    conn_str = client.get_secret("pg-connection-string").value
    
    return create_engine(conn_str)

# --- DATABASE VALIDATION ---

def test_five_tables_exist(engine):
    """The 'trading' schema must contain exactly 5 tables."""
    with engine.connect() as conn:
        query = text("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'trading' 
            ORDER BY table_name
        """)
        rows = conn.execute(query).fetchall()
        names = {r[0] for r in rows}
        
        # Note: Synced names to singular to match your validated SQL
        expected = {"instrument", "account", "trade", "position", "market_prices"}
        print(f"\nDEBUG: Connected to DB: {engine.url.database}")
        print(f"DEBUG: Found tables: {names}")
        assert names == expected, f"Unexpected tables found: {names}"

def test_trades_computed_column(engine):
    """The 'gross_value' must be a GENERATED ALWAYS AS STORED column."""
    with engine.connect() as conn:
        query = text("""
            SELECT is_generated 
            FROM information_schema.columns 
            WHERE table_schema = 'trading' 
              AND table_name = 'trade' 
              AND column_name = 'gross_value'
        """)
        row = conn.execute(query).fetchone()
        assert row is not None, "gross_value column not found in 'trade' table"
        assert row[0] == "ALWAYS", f"Expected generated status 'ALWAYS', got {row[0]}"

def test_ssl_connection(engine):
    """Connection must use SSL (enforced by Azure & connection string)."""
    with engine.connect() as conn:
        # PostgreSQL extension function to verify SSL
        result = conn.execute(text("SELECT ssl_is_used()")).scalar()
        assert result is True, "Security Breach: SSL is not active on this connection!"

# --- PROJECT ARTIFACTS ---

def test_simulator_output_exists():
    """Simulator must have produced at least one JSONL file in the output dir."""
    output_path = Path("simulator/output")
    files = list(output_path.glob("*.jsonl"))
    assert len(files) > 0, "No simulator data found. Run trade_generator.py first."

# --- SECURITY & COMPLIANCE ---

def test_no_hardcoded_credentials():
    """Scans all source files for leaked passwords or connection strings."""
    suspicious = re.compile(
        r"(password\s*=\s*['\"](?!\s*['\"])\S+['\"]|" 
        r"postgresql://\S+:\S+@|" 
        r"ARM_CLIENT_SECRET\s*=\s*['\"]\S+['\"])", 
        re.IGNORECASE
    )
    
    # Files/Dirs to ignore
    skip_files = {".env", "terraform.tfvars", "terraform.tfstate", "terraform.tfstate.backup"}
    skip_dirs = {"__pycache__", ".terraform", ".git", "venv", "venv_stable"}
    
    for p in Path(".").rglob("*"):
        # Filter for relevant source files
        if p.is_file() and p.suffix in {".py", ".tf", ".yml", ".yaml", ".sh"}:
            if any(s in p.parts for s in skip_dirs) or p.name in skip_files:
                continue
                
            content = p.read_text(errors="ignore")
            matches = suspicious.findall(content)
            
            # Show first two matches if leak is found
            assert not matches, f"Possible hardcoded credential leaked in {p}: {matches[:2]}"