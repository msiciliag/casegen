import sqlite3
import os

DB_PATH = 'casegen.db'

def get_connection():
    return sqlite3.connect(DB_PATH)

def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    # Create settings table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    ''')

    # Create history table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            challenge TEXT,
            solution TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    conn.commit()
    conn.close()

# Settings operations
def set_setting(key: str, value: str):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', (key, value))
    conn.commit()
    conn.close()

def get_setting(key: str, default: str = None) -> str:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT value FROM settings WHERE key = ?', (key,))
    result = cursor.fetchone()
    conn.close()
    if result:
        return result[0]
    return default

def get_api_key():
    return get_setting('api_key')

def set_api_key(api_key: str):
    set_setting('api_key', api_key)

# History operations
def add_history(challenge: str, solution: str):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO history (challenge, solution) VALUES (?, ?)', (challenge, solution))
    conn.commit()
    conn.close()

def get_history():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('SELECT id, challenge, solution, timestamp FROM history ORDER BY timestamp DESC')
    results = cursor.fetchall()
    conn.close()

    return [{'id': r[0], 'challenge': r[1], 'solution': r[2], 'timestamp': r[3]} for r in results]

def delete_history(history_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM history WHERE id = ?', (history_id,))
    conn.commit()
    conn.close()

# Initialize on import
init_db()
