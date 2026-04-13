import os
import psycopg2
from psycopg2 import sql
import pytest
from pathlib import Path
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from sqlalchemy import create_engine, text

def getKeyVaultUri() -> str:
    key_uri = os.environ.get("KEY_VAULT_URI")
    if not key_uri:
        raise ValueError("KEY_VAULT_URI environment variable not set.")
    return key_uri   

def getConnectionString() -> str:
    kv_uri = getKeyVaultUri
    cred = DefaultAzureCredential()
    client = SecretClient(vault_url=kv_uri, credential=cred)
    secret_name =  os.environ.get("SECRET_NAME","pg-connection-string")
    return client.get_secret(secret_name).value
    
def createDBEngine():
    return create_engine(
        getConnectionString(),
            connect_args={
            "sslmode":"require"
            }
        )

def execute_DDL():
    engine = createDBEngine()
    sql_path = Path("sql/ddl")
    scripts = sql_path.glob("*.sql")

    if not script:
        return (f"Warning: No SQL files found")
    
    for script in scripts:   
        print(f"Executing {script.name}...")
        try:
            with engine.begin() as conn:
                conn.execute(text(script.read_text()))
        except Exception as e:
            print(f"Error executing {script.name}: {e}")
            raise SystemExit
    print(f"doodle do bee do es kyu el script {len(script.name)} executed m'lord")

if __name__ == " __main__":
    execute_DDL()