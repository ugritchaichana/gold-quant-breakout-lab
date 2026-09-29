import os
import glob
import pandas as pd
import sqlite3

dir_path = os.path.dirname(os.path.abspath(__file__))
parts = sorted(glob.glob(os.path.join(dir_path, "quant_vault_full.parquet.part*")))
output_parquet = os.path.join(dir_path, "quant_vault_full.parquet")
output_db = os.path.join(os.path.dirname(dir_path), "quant_vault.db")

print(f"Reassembling {len(parts)} parts into {output_parquet}...")
with open(output_parquet, "wb") as f_out:
    for p in parts:
        with open(p, "rb") as f_in:
            f_out.write(f_in.read())

print("Rebuilding SQLite database quant_vault.db...")
df = pd.read_parquet(output_parquet)
conn = sqlite3.connect(output_db)
df.to_sql("results", conn, if_exists="replace", index=False)

c = conn.cursor()
print("Creating indexes...")
c.execute("CREATE INDEX IF NOT EXISTS idx_tf_cagr ON results (timeframe, full_cagr DESC);")
c.execute("CREATE INDEX IF NOT EXISTS idx_cagr_dd ON results (full_cagr DESC, full_dd ASC);")
c.execute("CREATE INDEX IF NOT EXISTS idx_oos_cagr ON results (oos_cagr DESC);")
c.execute("CREATE INDEX IF NOT EXISTS idx_full_pf ON results (full_pf DESC);")
conn.commit()
conn.close()
print(f"Done! Restored {len(df):,} rows into {output_db}")
