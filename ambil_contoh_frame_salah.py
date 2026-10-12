import csv
import random
from collections import defaultdict
from pathlib import Path

INPUT_FILE = Path("detail_frame_rentang_fitur_liveness.csv")
OUTPUT_FILE = Path("contoh_20_frame_salah_liveness.csv")

FEATURES = [
    "laplacian_variance",
    "edge_density",
    "intensity_mean",
    "intensity_std",
]

def norm(value):
    return str(value or "").strip().upper().replace(" ", "_")

def find_column(fieldnames, candidates):
    lookup = {str(name).strip().lower(): name for name in fieldnames}
    for candidate in candidates:
        if candidate.lower() in lookup:
            return lookup[candidate.lower()]
    return None

if not INPUT_FILE.exists():
    raise SystemExit(
        f"File tidak ditemukan: {INPUT_FILE.resolve()}\n"
        "Pastikan skrip ini dan detail_frame_rentang_fitur_liveness.csv "
        "berada di folder project yang sama."
    )

with INPUT_FILE.open("r", newline="", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    if not reader.fieldnames:
        raise SystemExit("CSV tidak memiliki header kolom.")
    rows = list(reader)
    fields = reader.fieldnames

label_col = find_column(fields, ["label_asli", "label", "kondisi", "actual_label", "true_label"])
pred_col = find_column(fields, ["prediksi", "prediction", "predicted_label", "hasil_prediksi"])
distance_col = find_column(fields, ["jarak", "distance"])
session_col = find_column(fields, ["session_id", "session", "sesi"])
frame_col = find_column(fields, ["frame", "frame_number", "nomor_frame"])

missing = []
if not label_col: missing.append("label_asli/label")
if not pred_col: missing.append("prediksi")
if not distance_col: missing.append("jarak")
if not session_col: missing.append("session_id/sesi")
if not frame_col: missing.append("frame")
missing_features = [name for name in FEATURES if name not in fields]

if missing or missing_features:
    raise SystemExit(
        "Kolom wajib belum ditemukan.\n"
        f"Kolom label/prediksi/sesi/jarak yang tidak ditemukan: {missing}\n"
        f"Fitur yang tidak ditemukan: {missing_features}\n"
        f"Kolom CSV yang tersedia: {fields}"
    )

def binary_class(value):
    v = norm(value)
    if v in {"REAL", "BENAR", "LIVE", "1"} or v.startswith("REAL_"):
        return "REAL"
    if v in {"REPLAY", "FOTO_LAYAR", "ATTACK", "SPOOF", "NON_REAL", "0"}:
        return "ATTACK"
    if v.startswith("REPLAY_") or v.startswith("FOTO_LAYAR_"):
        return "ATTACK"
    return v

errors = []
for row in rows:
    actual = binary_class(row.get(label_col))
    predicted = binary_class(row.get(pred_col))
    if actual == predicted:
        continue

    if actual == "REAL" and predicted == "ATTACK":
        error_type = "REAL_SALAH_DITOLAK (FN)"
    elif actual == "ATTACK" and predicted == "REAL":
        error_type = "SERANGAN_SALAH_DITERIMA (FP)"
    else:
        error_type = f"SALAH: {actual} -> {predicted}"

    output_row = dict(row)
    output_row["jenis_kesalahan"] = error_type
    errors.append(output_row)

if not errors:
    raise SystemExit(
        "Tidak ditemukan frame salah. Periksa apakah kolom label dan prediksi "
        "pada file berisi nilai yang sesuai."
    )

# Pilih sampai 10 contoh per jenis kesalahan, dibagi merata menurut jarak.
# Pemilihan deterministik agar hasil yang dihasilkan bisa diulang.
by_type_distance = defaultdict(list)
for row in errors:
    by_type_distance[(row["jenis_kesalahan"], norm(row.get(distance_col)))].append(row)

for group in by_type_distance.values():
    group.sort(key=lambda r: (str(r.get(session_col, "")), str(r.get(frame_col, ""))))

types = sorted({r["jenis_kesalahan"] for r in errors})
selected = []
for error_type in types:
    distances = sorted({distance for (kind, distance) in by_type_distance if kind == error_type})
    # Round-robin antar jarak supaya contoh tidak hanya berasal dari satu jarak.
    groups = [by_type_distance[(error_type, distance)] for distance in distances]
    per_type_limit = 10
    index = 0
    while len([r for r in selected if r["jenis_kesalahan"] == error_type]) < per_type_limit:
        added = False
        for group in groups:
            if index < len(group):
                selected.append(group[index])
                added = True
                if len([r for r in selected if r["jenis_kesalahan"] == error_type]) >= per_type_limit:
                    break
        if not added:
            break
        index += 1

# Batasi total maksimum 20 baris; jika ada dua jenis kesalahan, target hingga 10 per jenis.
selected = selected[:20]

preferred = [
    session_col, frame_col,
    label_col, pred_col, distance_col,
    "jenis_kesalahan",
    *FEATURES,
]
# Sertakan timestamp jika tersedia, lalu kolom metadata lainnya.
if find_column(fields, ["timestamp", "time"]):
    ts_col = find_column(fields, ["timestamp", "time"])
    preferred.insert(2, ts_col)
output_fields = []
for name in preferred + fields:
    if name not in output_fields and (name in fields or name == "jenis_kesalahan"):
        output_fields.append(name)

with OUTPUT_FILE.open("w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=output_fields, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(selected)

print("SELESAI")
print(f"Total frame salah pada data: {len(errors)}")
print(f"Contoh frame yang disimpan: {len(selected)}")
print(f"File hasil: {OUTPUT_FILE.resolve()}")
print("\nJumlah contoh per jenis kesalahan:")
counts = defaultdict(int)
for row in selected:
    counts[row["jenis_kesalahan"]] += 1
for kind, count in sorted(counts.items()):
    print(f"- {kind}: {count}")

print("\nContoh kolom yang disertakan:")
print(", ".join(output_fields))
print("\nCatatan: REPLAY dan FOTO_LAYAR digabung sebagai ATTACK/non-REAL "
      "untuk evaluasi biner, karena model saat ini hanya memprediksi REAL atau REPLAY.")
