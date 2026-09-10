import sqlite3

import os

db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'myschemes.db')
conn = sqlite3.connect(db_path)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM schemes')
print('Total schemes:', c.fetchone()[0])

c.execute("SELECT COUNT(*) FROM schemes WHERE category LIKE '%Health%'")
print('Health schemes:', c.fetchone()[0])

c.execute('SELECT id, name, eligible_gender, age_min, age_max, eligible_state FROM schemes WHERE category LIKE "%Health%" LIMIT 5')
for row in c.fetchall():
    print('Row:', row)

conn.close()
