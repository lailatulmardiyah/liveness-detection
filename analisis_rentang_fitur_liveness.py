import csv, math, os, statistics
from collections import defaultdict

INPUT = 'hasil_evaluasi_liveness.csv'
OUTPUT_RANGE = 'analisis_rentang_fitur_liveness.csv'
OUTPUT_DETAIL = 'detail_frame_rentang_fitur_liveness.csv'
FEATURES = ['laplacian_variance', 'edge_density', 'intensity_mean', 'intensity_std']

def norm(row, key):
    return str(row.get(key, '')).strip().upper()

def number(row, key):
    try:
        value = float(row.get(key, ''))
        return value if math.isfinite(value) else None
    except (TypeError, ValueError):
        return None

def percentile(values, p):
    values = sorted(values)
    if not values: return None
    if len(values) == 1: return values[0]
    pos = (len(values)-1)*p
    lo, hi = int(math.floor(pos)), int(math.ceil(pos))
    return values[lo] if lo == hi else values[lo] + (values[hi]-values[lo])*(pos-lo)

def fmt(v): return '' if v is None else f'{v:.6f}'

if not os.path.exists(INPUT):
    raise SystemExit(f"File '{INPUT}' tidak ditemukan. Simpan skrip ini di folder yang sama dengan hasil_evaluasi_liveness.csv.")
with open(INPUT, encoding='utf-8-sig', newline='') as f:
    rows = list(csv.DictReader(f))
if not rows: raise SystemExit('CSV kosong atau tidak memiliki baris data.')
required = ['label_asli', 'prediksi'] + FEATURES
missing = [c for c in required if c not in rows[0]]
if missing:
    print('Kolom tersedia:', ', '.join(rows[0].keys()))
    raise SystemExit('Kolom wajib tidak ditemukan: ' + ', '.join(missing))

def error_type(row):
    actual, pred = norm(row, 'label_asli'), norm(row, 'prediksi')
    if actual == 'REAL' and pred == 'REPLAY': return 'REAL_SALAH_DITOLAK'
    if actual in ('REPLAY', 'FOTO_LAYAR') and pred == 'REAL': return 'SERANGAN_SALAH_DITERIMA'
    return 'BENAR'
for row in rows:
    row['_jenis_kesalahan'] = error_type(row)
    row['_salah'] = row['_jenis_kesalahan'] != 'BENAR'
errors = [r for r in rows if r['_salah']]
correct = [r for r in rows if not r['_salah']]
print('='*78, '\nANALISIS RENTANG FITUR YANG BERKAITAN DENGAN KESALAHAN', sep='')
print(f'Jumlah frame: {len(rows)} | Salah: {len(errors)} ({100*len(errors)/len(rows):.2f}%) | Benar: {len(correct)} ({100*len(correct)/len(rows):.2f}%)')
print('Rentang dibentuk dari kuantil P10, P25, P50, P75, P90 data; ini bukan ambang universal.')
summary=[]
for feature in FEATURES:
    pairs=[(number(r,feature),r) for r in rows]
    pairs=[(v,r) for v,r in pairs if v is not None]
    vals=[v for v,r in pairs]
    if not vals: continue
    ranges=[('P10-P25',percentile(vals,.10),percentile(vals,.25)),('P25-P50',percentile(vals,.25),percentile(vals,.50)),('P50-P75',percentile(vals,.50),percentile(vals,.75)),('P75-P90',percentile(vals,.75),percentile(vals,.90))]
    baseline=100*sum(r['_salah'] for v,r in pairs)/len(pairs)
    print('\n'+'-'*78, f'\nFITUR: {feature}')
    print(f"{'Rentang':<12}{'Batas bawah':>15}{'Batas atas':>15}{'Jumlah':>9}{'Salah':>9}{'% salah':>11}{'vs dasar':>12}")
    for i,(label,low,high) in enumerate(ranges):
        bucket=[(v,r) for v,r in pairs if v>=low and (v<high or (i==len(ranges)-1 and v<=high))]
        if not bucket: continue
        n=len(bucket); wrong=sum(r['_salah'] for v,r in bucket); rate=100*wrong/n; delta=rate-baseline
        print(f'{label:<12}{low:>15.4f}{high:>15.4f}{n:>9}{wrong:>9}{rate:>10.2f}%{delta:>+10.2f} pp')
        summary.append({'fitur':feature,'rentang_kuantil':label,'batas_bawah':fmt(low),'batas_atas':fmt(high),'jumlah_frame':n,'jumlah_salah':wrong,'persentase_salah':fmt(rate),'baseline_persen_salah':fmt(baseline),'selisih_dari_baseline_poin_persen':fmt(delta),'REAL_salah_ditolak':sum(r['_jenis_kesalahan']=='REAL_SALAH_DITOLAK' for v,r in bucket),'serangan_salah_diterima':sum(r['_jenis_kesalahan']=='SERANGAN_SALAH_DITERIMA' for v,r in bucket)})
print('\n'+'='*78+'\nPERBANDINGAN FRAME BENAR VS SALAH')
print(f"{'Fitur':<24}{'Median benar':>15}{'Median salah':>15}{'P25-P75 benar':>25}{'P25-P75 salah':>25}")
for feature in FEATURES:
    good=[number(r,feature) for r in correct]; bad=[number(r,feature) for r in errors]
    good=[v for v in good if v is not None]; bad=[v for v in bad if v is not None]
    if good and bad:
        gr=f'{percentile(good,.25):.4f}-{percentile(good,.75):.4f}'; br=f'{percentile(bad,.25):.4f}-{percentile(bad,.75):.4f}'
        print(f'{feature:<24}{statistics.median(good):>15.4f}{statistics.median(bad):>15.4f}{gr:>25}{br:>25}')
print('\n'+'='*78+'\nKESALAHAN BERDASARKAN LABEL DAN JARAK')
if 'jarak' in rows[0]:
    groups=defaultdict(list)
    for r in rows: groups[(norm(r,'label_asli'),norm(r,'jarak') or 'TIDAK_DIKETAHUI')].append(r)
    print(f"{'Label':<15}{'Jarak':<14}{'Frame':>8}{'Salah':>8}{'% salah':>11}")
    for (label,distance), group in sorted(groups.items()):
        wrong=sum(r['_salah'] for r in group); rate=100*wrong/len(group)
        print(f'{label:<15}{distance:<14}{len(group):>8}{wrong:>8}{rate:>10.2f}%')
else: print("Kolom 'jarak' tidak ada; ringkasan jarak dilewati.")
if summary:
    with open(OUTPUT_RANGE,'w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(summary[0].keys())); writer.writeheader(); writer.writerows(summary)
detail=[]
for r in rows:
    out={k:v for k,v in r.items() if not k.startswith('_')}; out['jenis_kesalahan']=r['_jenis_kesalahan']; detail.append(out)
with open(OUTPUT_DETAIL,'w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(detail[0].keys())); writer.writeheader(); writer.writerows(detail)
print('\nFile hasil tersimpan:')
print('1.',os.path.abspath(OUTPUT_RANGE)); print('2.',os.path.abspath(OUTPUT_DETAIL))
print('Interpretasi: persentase salah di atas baseline menunjukkan asosiasi, bukan sebab-akibat. Perhatikan jumlah sampel dan korelasi antarframe satu sesi.')
