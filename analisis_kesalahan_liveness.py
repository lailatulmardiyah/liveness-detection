import csv
import math
import os
import statistics
from collections import Counter, defaultdict

INPUT = "hasil_evaluasi_liveness.csv"
OUTPUT = "analisis_kesalahan_liveness.csv"

FEATURES = [
    "laplacian_variance",
    "edge_density",
    "intensity_mean",
    "intensity_std",
]

def number(row, key):
    try:
        value = float(row.get(key, ""))
        return value if math.isfinite(value) else None
    except (TypeError, ValueError):
        return None

def mean(values):
    return statistics.mean(values) if values else None

def fmt(value):
    return "NA" if value is None else f"{value:.4f}"

if not os.path.exists(INPUT):
    raise SystemExit(
        f"File {INPUT} tidak ditemukan. Simpan skrip ini di folder yang sama "
        "dengan hasil_evaluasi_liveness.csv, lalu jalankan kembali."
    )

with open(INPUT, encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

if not rows:
    raise SystemExit("CSV kosong atau tidak memiliki baris data.")

# Kelompok kesalahan
false_negative = [
    r for r in rows
    if r.get("label_asli", "").strip().upper() == "REAL"
    and r.get("prediksi", "").strip().upper() == "REPLAY"
]
false_positive = [
    r for r in rows
    if r.get("label_asli", "").strip().upper() in ("REPLAY", "FOTO_LAYAR")
    and r.get("prediksi", "").strip().upper() == "REAL"
]

print("=" * 72)
print("RINGKASAN KESALAHAN")
print("=" * 72)
print(f"Total baris: {len(rows)}")
print(f"REAL salah menjadi REPLAY (false negative): {len(false_negative)}")
print(f"REPLAY/FOTO_LAYAR salah menjadi REAL (false positive): {len(false_positive)}")

print("\n" + "=" * 72)
print("KESALAHAN BERDASARKAN KONDISI DAN JARAK")
print("=" * 72)
print(f"{'Kondisi':<14} {'Jarak':<10} {'Frame':>7} {'Salah':>7} {'% salah':>10}")
groups = defaultdict(list)
for r in rows:
    groups[(r.get("kondisi", "?").strip().upper(),
             r.get("jarak", "?").strip().upper())].append(r)

for (condition, distance), group in sorted(groups.items()):
    wrong = sum(r.get("hasil", "").strip().upper() != "BENAR" for r in group)
    pct = 100 * wrong / len(group) if group else 0
    print(f"{condition:<14} {distance:<10} {len(group):>7} {wrong:>7} {pct:>9.2f}%")

print("\n" + "=" * 72)
print("PERBANDINGAN FITUR: REAL BENAR vs REAL SALAH")
print("=" * 72)
real_correct = [
    r for r in rows
    if r.get("label_asli", "").strip().upper() == "REAL"
    and r.get("prediksi", "").strip().upper() == "REAL"
]
print(f"REAL benar: {len(real_correct)} | REAL salah: {len(false_negative)}")
print(f"{'Fitur':<24} {'REAL benar (mean)':>20} {'REAL salah (mean)':>20}")
for feature in FEATURES:
    correct_values = [number(r, feature) for r in real_correct]
    wrong_values = [number(r, feature) for r in false_negative]
    correct_values = [v for v in correct_values if v is not None]
    wrong_values = [v for v in wrong_values if v is not None]
    print(f"{feature:<24} {fmt(mean(correct_values)):>20} {fmt(mean(wrong_values)):>20}")

print("\n" + "=" * 72)
print("KARAKTERISTIK REAL YANG SALAH PER JARAK")
print("=" * 72)
print(f"{'Jarak':<10} {'Salah/total':>14} {'Lap mean':>12} {'Edge mean':>12} {'Int mean':>12} {'Std mean':>12}")
for distance in ("DEKAT", "SEDANG", "JAUH"):
    all_real = [
        r for r in rows
        if r.get("label_asli", "").strip().upper() == "REAL"
        and r.get("jarak", "").strip().upper() == distance
    ]
    wrong = [r for r in all_real if r.get("prediksi", "").strip().upper() == "REPLAY"]
    feature_means = []
    for feature in FEATURES:
        vals = [number(r, feature) for r in wrong]
        feature_means.append(mean([v for v in vals if v is not None]))
    print(f"{distance:<10} {len(wrong):>5}/{len(all_real):<8} "
          f"{fmt(feature_means[0]):>12} {fmt(feature_means[1]):>12} "
          f"{fmt(feature_means[2]):>12} {fmt(feature_means[3]):>12}")

print("\n" + "=" * 72)
print("CONFIDENCE VOTE: KESALAHAN")
print("=" * 72)
for title, group in (("REAL salah menjadi REPLAY", false_negative),
                     ("Serangan salah menjadi REAL", false_positive)):
    vals = [number(r, "confidence_vote_fraction") for r in group]
    vals = [v for v in vals if v is not None]
    print(f"{title}: n={len(vals)}, mean={fmt(mean(vals))}, "
          f"median={fmt(statistics.median(vals) if vals else None)}, "
          f"min={fmt(min(vals) if vals else None)}, max={fmt(max(vals) if vals else None)}")

# Export semua baris salah, tanpa mengubah file sumber.
wrong_rows = []
for r in rows:
    actual = r.get("label_asli", "").strip().upper()
    pred = r.get("prediksi", "").strip().upper()
    if (actual == "REAL" and pred == "REPLAY") or (
        actual in ("REPLAY", "FOTO_LAYAR") and pred == "REAL"
    ):
        copied = dict(r)
        copied["jenis_kesalahan"] = (
            "REAL_SALAH_DITOLAK" if actual == "REAL"
            else "SERANGAN_SALAH_DITERIMA"
        )
        wrong_rows.append(copied)

fieldnames = list(rows[0].keys())
if "jenis_kesalahan" not in fieldnames:
    fieldnames.append("jenis_kesalahan")
with open(OUTPUT, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(wrong_rows)

print(f"\nFile detail kesalahan tersimpan: {os.path.abspath(OUTPUT)}")
print("Catatan: hasil ini bersifat diagnostik; frame dalam satu sesi saling berkaitan.")
