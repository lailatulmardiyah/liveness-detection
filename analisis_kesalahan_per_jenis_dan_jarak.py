import csv
import math
import os
from collections import defaultdict

INPUT = "detail_frame_rentang_fitur_liveness.csv"
OUTPUT = "analisis_kesalahan_per_jenis_dan_jarak.csv"

FEATURES = [
    "laplacian_variance",
    "edge_density",
    "intensity_mean",
    "intensity_std",
]

def norm(row, key):
    return str(row.get(key, "")).strip().upper()

def num(row, key):
    try:
        x = float(row.get(key, ""))
        return x if math.isfinite(x) else None
    except (ValueError, TypeError):
        return None

def median(values):
    values = sorted(values)
    n = len(values)
    if not n:
        return None
    mid = n // 2
    if n % 2:
        return values[mid]
    return (values[mid - 1] + values[mid]) / 2

def quantile(values, p):
    values = sorted(values)
    if not values:
        return None
    pos = (len(values) - 1) * p
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return values[lo]
    return values[lo] + (values[hi] - values[lo]) * (pos - lo)

def fmt(x):
    return "" if x is None else f"{x:.6f}"

if not os.path.exists(INPUT):
    raise SystemExit(
        f"File '{INPUT}' tidak ditemukan. Pastikan file hasil skrip sebelumnya "
        "ada di folder proyek yang sama."
    )

with open(INPUT, encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

if not rows:
    raise SystemExit("File input kosong.")

required = ["label_asli", "prediksi", "jarak"] + FEATURES
missing = [key for key in required if key not in rows[0]]
if missing:
    print("Kolom yang tersedia:", ", ".join(rows[0].keys()))
    raise SystemExit("Kolom wajib tidak ditemukan: " + ", ".join(missing))

# Pisahkan kesalahan berdasarkan arah prediksi.
for row in rows:
    actual = norm(row, "label_asli")
    pred = norm(row, "prediksi")
    if actual == "REAL" and pred == "REPLAY":
        row["_error_type"] = "REAL_SALAH_DITOLAK"
    elif actual in ("REPLAY", "FOTO_LAYAR") and pred == "REAL":
        row["_error_type"] = "SERANGAN_SALAH_DITERIMA"
    else:
        row["_error_type"] = "BENAR"
    row["_condition"] = actual
    row["_distance"] = norm(row, "jarak") or "TIDAK_DIKETAHUI"

print("=" * 88)
print("ANALISIS JENIS KESALAHAN MENURUT KONDISI DAN JARAK")
print("=" * 88)

# Tabel hitungan kesalahan per label dan jarak.
groups = defaultdict(list)
for row in rows:
    groups[(row["_condition"], row["_distance"])].append(row)

print("\n1) Tingkat kesalahan per label dan jarak")
print(f"{'Label':<15}{'Jarak':<14}{'Jumlah':>9}{'Benar':>9}{'Salah':>9}{'% salah':>11}")
for (label, distance), group in sorted(groups.items()):
    wrong = sum(r["_error_type"] != "BENAR" for r in group)
    correct = len(group) - wrong
    rate = 100 * wrong / len(group) if group else 0
    print(f"{label:<15}{distance:<14}{len(group):>9}{correct:>9}{wrong:>9}{rate:>10.2f}%")

# Statistik fitur untuk frame benar dan setiap arah kesalahan.
print("\n" + "=" * 88)
print("2) Median dan rentang P25-P75 fitur menurut jenis kesalahan")
print("Median/rentang dihitung dari frame yang tersedia pada setiap kelompok.")
print("=" * 88)
categories = [
    ("BENAR", "Prediksi benar"),
    ("REAL_SALAH_DITOLAK", "REAL salah ditolak"),
    ("SERANGAN_SALAH_DITERIMA", "Serangan salah diterima"),
]
stats_rows = []
for error_code, error_label in categories:
    subset = [r for r in rows if r["_error_type"] == error_code]
    print(f"\n{error_label}: {len(subset)} frame")
    if not subset:
        continue
    print(f"{'Fitur':<24}{'Median':>14}{'P25':>14}{'P75':>14}")
    for feature in FEATURES:
        values = [num(r, feature) for r in subset]
        values = [v for v in values if v is not None]
        if not values:
            continue
        med = median(values)
        p25 = quantile(values, .25)
        p75 = quantile(values, .75)
        print(f"{feature:<24}{med:>14.4f}{p25:>14.4f}{p75:>14.4f}")
        stats_rows.append({
            "kelompok_kesalahan": error_code,
            "jumlah_frame_kelompok": len(subset),
            "fitur": feature,
            "median": fmt(med),
            "p25": fmt(p25),
            "p75": fmt(p75),
        })

# Ringkasan error per jarak, untuk memisahkan REAL FN dan serangan FP.
print("\n" + "=" * 88)
print("3) Jenis kesalahan menurut jarak")
print("=" * 88)
distances = sorted({r["_distance"] for r in rows})
print(f"{'Jarak':<14}{'REAL salah ditolak':>22}{'Serangan salah diterima':>27}")
for distance in distances:
    subset = [r for r in rows if r["_distance"] == distance]
    fn = sum(r["_error_type"] == "REAL_SALAH_DITOLAK" for r in subset)
    fp = sum(r["_error_type"] == "SERANGAN_SALAH_DITERIMA" for r in subset)
    print(f"{distance:<14}{fn:>22}{fp:>27}")

# Statistik per fitur dan jenis kesalahan x jarak; file ini untuk Excel.
detail_summary = []
for distance in distances:
    for error_code, error_label in categories:
        subset = [r for r in rows if r["_distance"] == distance and r["_error_type"] == error_code]
        if not subset:
            continue
        for feature in FEATURES:
            vals = [num(r, feature) for r in subset]
            vals = [v for v in vals if v is not None]
            if not vals:
                continue
            detail_summary.append({
                "jarak": distance,
                "kelompok_kesalahan": error_code,
                "jumlah_frame": len(subset),
                "fitur": feature,
                "median": fmt(median(vals)),
                "p25": fmt(quantile(vals, .25)),
                "p75": fmt(quantile(vals, .75)),
                "minimum": fmt(min(vals)),
                "maksimum": fmt(max(vals)),
            })

with open(OUTPUT, "w", encoding="utf-8-sig", newline="") as f:
    fields = list(detail_summary[0].keys()) if detail_summary else [
        "jarak", "kelompok_kesalahan", "jumlah_frame", "fitur",
        "median", "p25", "p75", "minimum", "maksimum"
    ]
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(detail_summary)

print("\nFile ringkasan untuk dibuka di Excel:")
print(os.path.abspath(OUTPUT))
print("\nCatatan:")
print("- REAL_SALAH_DITOLAK berarti wajah REAL diprediksi REPLAY.")
print("- SERANGAN_SALAH_DITERIMA berarti REPLAY/FOTO_LAYAR diprediksi REAL.")
print("- Statistik deskriptif ini menunjukkan asosiasi, bukan sebab-akibat.")
print("- Frame dari sesi yang sama berkorelasi; validasi sebaiknya dilakukan per sesi.")
