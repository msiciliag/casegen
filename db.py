import sqlite3

DB_PATH = 'casegen.db'

def get_connection():
    return sqlite3.connect(DB_PATH)

def init_db():
    conn = get_connection()
    cursor = conn.cursor()

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
    cursor.execute('SELECT id, challenge, solution, timestamp FROM history ORDER BY timestamp DESC, id DESC')
    results = cursor.fetchall()
    conn.close()

    return [{'id': r[0], 'challenge': r[1], 'solution': r[2], 'timestamp': r[3]} for r in results]

def delete_history(history_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute('DELETE FROM history WHERE id = ?', (history_id,))
    conn.commit()
    conn.close()
