import pandas as pd
from pathlib import Path
from collections import Counter
import json

# --- 1) Load the CSV ---------------------------------------------------------
src = Path(mntdataclimate_change_impact_on_agriculture_2024.csv)

try
    df = pd.read_csv(src)
except UnicodeDecodeError
    df = pd.read_csv(src, encoding=latin-1)

# --- 2) Auto-detect the country column --------------------------------------
candidate_cols = [c for c in df.columns if isinstance(c, str)]
lc_map = {c c.lower() for c in candidate_cols}

country_like = [
    country, country_name, nation, entity, location, area, region
]

country_col = None
# First pass directsubstring matches to common country-like column names
for c in candidate_cols
    if any(tok == lc_map[c] for tok in country_like) or any(tok in lc_map[c] for tok in country_like)
        country_col = c
        break

# Fallback heuristic pick a text column with repeated labels that looks country-ish
if country_col is None
    text_cols = [c for c in candidate_cols if df[c].dtype == object]
    best_col, best_score = None, -1
    for c in text_cols
        n_unique = df[c].nunique(dropna=True)
        if 2 = n_unique = max(100, len(df)10)  # heuristic bounds
            sample_vals = df[c].dropna().astype(str).head(200).tolist()
            cap_ratio = sum(v[1].isupper() for v in sample_vals)max(1,len(sample_vals))
            score = (len(df) - n_unique) + 5cap_ratio
            if score  best_score
                best_score = score
                best_col = c
    country_col = best_col

if country_col is None
    # Fail loudly if not found
    info = {error Could not automatically detect the country column.,
            columns_available candidate_cols}
    raise RuntimeError(json.dumps(info, indent=2))

print(f[info] Detected country column {country_col})

# --- 3) Normalize values for matching ---------------------------------------
def norm(s)
    return str(s).strip().lower()

df[_country_norm] = df[country_col].map(norm)

# --- 4) Canonical names + common variants -----------------------------------
targets = {
    United States [united states, usa, u.s., u.s.a, united states of america],
    China [china, people's republic of china, pr china, prc],
    Canada [canada],
    Australia [australia],
    India [india],
}

def matches_any(name_norm str)
    for canonical, keys in targets.items()
        for k in keys
            if k in name_norm
                return canonical
    return None

df[_selected_country] = df[_country_norm].map(matches_any)

# --- 5) Split datasets -------------------------------------------------------
df_top5 = df[df[_selected_country].notna()].copy()
df_excluding_top5 = df[df[_selected_country].isna()].copy()

# --- 6) Save both versions ---------------------------------------------------
out_top5 = Path(mntdataclimate_agri_top5_countries.csv)
out_excl = Path(mntdataclimate_agri_excluding_top5.csv)

df_top5.drop(columns=[_country_norm], errors=ignore).to_csv(out_top5, index=False)
df_excluding_top5.drop(columns=[_country_norm], errors=ignore).to_csv(out_excl, index=False)

# --- 7) Quick summary --------------------------------------------------------
counts = Counter(df_top5[_selected_country])
print([summary])
print(f  total_rows {len(df)})
print(f  rows_in_top5_subset {len(df_top5)})
print(f  rows_excluding_top5 {len(df_excluding_top5)})
print(f  per_country_counts_in_top5_subset {dict(counts)})
