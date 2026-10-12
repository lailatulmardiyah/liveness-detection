
import csv
import json
import math
from collections import defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent
MODEL_FILE = BASE / "assets" / "models" / "liveness_random_forest.json"
CSV_FILE = BASE / "face_liveness_9_sesi_berlabel.csv"
OUTPUT_FILE = BASE / "hasil_evaluasi_liveness.csv"

FEATURES = [
    "laplacian_variance",
    "edge_density",
    "intensity_mean",
    "intensity_std",
]

def predict(model, x):
    real_votes = 0
    replay_votes = 0

    for tree in model["trees"]:
        left = tree["children_left"]
        right = tree["children_right"]
        feature = tree["feature"]
        threshold = tree["threshold"]
        values = tree["value"]

        node = 0
        while left[node] != -1 and right[node] != -1:
            j = feature[node]
            node = left[node] if x[j] <= threshold[node] else right[node]

        counts = values[node]
        predicted_class = 1 if counts[1] >= counts[0] else 0

        if predicted_class == 1:
            real_votes += 1
        else:
            replay_votes += 1

    is_real = real_votes > replay_votes
    total = real_votes + replay_votes

    return (
        "REAL" if is_real else "REPLAY",
        real_votes,
        replay_votes,
        (real_votes if is_real else replay_votes) / total if total else 0,
    )

def metrics(rows, positive_label):
    tp = sum(r["label_asli"] == positive_label and
             r["prediksi"] == positive_label for r in rows)
    fn = sum(r["label_asli"] == positive_label and
             r["prediksi"] != positive_label for r in rows)
    fp = sum(r["label_asli"] != positive_label and
             r["prediksi"] == positive_label for r in rows)
    tn = sum(r["label_asli"] != positive_label and
             r["prediksi"] != positive_label for r in rows)

    n = len(rows)
    accuracy = (tp + tn) / n if n else 0
    recall_positive = tp / (tp + fn) if tp + fn else 0
    recall_negative = tn / (tn + fp) if tn + fp else 0
    balanced = (recall_positive + recall_negative) / 2

    return {
        "jumlah_frame": n,
        "TP": tp, "FN": fn, "FP": fp, "TN": tn,
        "akurasi": round(accuracy * 100, 2),
        "recall_positif": round(recall_positive * 100, 2),
        "recall_negatif": round(recall_negative * 100, 2),
        "balanced_accuracy": round(balanced * 100, 2),
    }

def show_metrics(title, rows, positive_label):
    m = metrics(rows, positive_label)
    print(f"\n{title} (label positif: {positive_label})")
    print("-" * 56)
    for key, value in m.items():
        print(f"{key}: {value}")

def main():
    with MODEL_FILE.open("r", encoding="utf-8") as f:
        model = json.load(f)

    print("Jumlah pohon model:", len(model["trees"]))

    with CSV_FILE.open("r", encoding="utf-8-sig", newline="") as f:
        source_rows = list(csv.DictReader(f))

    results = []
    for row in source_rows:
        if not row.get("session_id") or not row.get("kondisi"):
            continue

        condition = row["kondisi"].strip().upper()
        distance = row["jarak"].strip().upper()

        # Evaluasi biner: REAL vs seluruh jenis serangan.
        label_asli = "REAL" if condition == "REAL" else "REPLAY"

        try:
            x = [float(row[name]) for name in FEATURES]
        except (KeyError, ValueError):
            continue

        if not all(math.isfinite(v) for v in x):
            continue

        prediction, rv, pv, vote_fraction = predict(model, x)

        results.append({
            **row,
            "label_asli": label_asli,
            "prediksi": prediction,
            "hasil": "BENAR" if prediction == label_asli else "SALAH",
            "real_votes": rv,
            "replay_votes": pv,
            "confidence_vote_fraction": round(vote_fraction, 6),
        })

    if not results:
        raise RuntimeError("Tidak ada baris valid. Periksa CSV berlabel.")

    with OUTPUT_FILE.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(results[0].keys()))
        writer.writeheader()
        writer.writerows(results)

    # Evaluasi keseluruhan: REAL dibandingkan REPLAY + FOTO_LAYAR.
    show_metrics("SELURUH FRAME", results, "REAL")

    # Evaluasi terpisah per jenis serangan.
    for condition in ["REAL", "REPLAY", "FOTO_LAYAR"]:
        subset = [r for r in results if r["kondisi"].upper() == condition]
        if not subset:
            continue
        correct = sum(r["hasil"] == "BENAR" for r in subset)
        print(f"\n{condition}: {correct}/{len(subset)} prediksi sesuai label "
              f"({correct / len(subset) * 100:.2f}%)")

    # Evaluasi per kondisi dan jarak.
    print("\nRINGKASAN PER KONDISI DAN JARAK")
    print("=" * 75)
    groups = defaultdict(list)
    for row in results:
        groups[(row["kondisi"].upper(), row["jarak"].upper())].append(row)

    for (condition, distance), subset in sorted(groups.items()):
        correct = sum(r["hasil"] == "BENAR" for r in subset)
        print(f"{condition:12} {distance:8} "
              f"frame={len(subset):3} "
              f"benar={correct:3} "
              f"akurasi={correct / len(subset) * 100:6.2f}%")

    # Ringkasan per sesi: setiap sesi dihitung sebagai satu unit.
    print("\nRINGKASAN PER SESI (MAYORITAS FRAME)")
    print("=" * 75)
    sessions = defaultdict(list)
    for row in results:
        sessions[row["session_id"]].append(row)

    session_results = []
    for session_id, subset in sessions.items():
        condition = subset[0]["kondisi"].upper()
        label = "REAL" if condition == "REAL" else "REPLAY"
        real_count = sum(r["prediksi"] == "REAL" for r in subset)
        replay_count = len(subset) - real_count
        prediction = "REAL" if real_count > replay_count else "REPLAY"
        correct = prediction == label
        session_results.append(correct)
        print(f"{condition:12} {subset[0]['jarak']:8} "
              f"frame={len(subset):3} prediksi={prediction:6} "
              f"benar={'YA' if correct else 'TIDAK'}")

    print(f"\nAkurasi sesi: {sum(session_results)}/{len(session_results)} "
          f"({sum(session_results) / len(session_results) * 100:.2f}%)")
    print("\nCSV hasil prediksi:", OUTPUT_FILE)

if __name__ == "__main__":
    main()