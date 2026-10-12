# ANALISIS TEXTURE - REAL vs REPLAY
# Letakkan file ini satu folder dengan:
# face_liveness_texture_data_2026-09-29.csv
#
# Jalankan:
# .\analisis_texture.ps1

$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputCsv = Join-Path $base "face_liveness_texture_data_2026-09-29.csv"
$outDir = Join-Path $base "texture_analysis_results"

if (-not (Test-Path $inputCsv)) {
    throw "CSV tidak ditemukan: $inputCsv"
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$data = @(Import-Csv $inputCsv)

$realSessions = @(
"2026-09-29T10:34:22.387341",
"2026-09-29T10:35:00.659042",
"2026-09-29T10:35:34.342737",
"2026-09-29T10:36:08.750186",
"2026-09-29T10:39:14.161685",
"2026-09-29T10:39:48.298497",
"2026-09-29T10:41:07.948977",
"2026-09-29T10:41:42.959836",
"2026-09-29T10:42:16.509675",
"2026-09-29T10:42:45.544491"
)
$replaySessions = @(
"2026-09-29T13:35:21.281663",
"2026-09-29T13:35:50.528220",
"2026-09-29T13:36:10.306428",
"2026-09-29T13:36:31.271680",
"2026-09-29T13:37:24.221038",
"2026-09-29T13:37:57.919279",
"2026-09-29T13:38:28.637294",
"2026-09-29T13:38:50.875124",
"2026-09-29T13:39:24.806960",
"2026-09-29T13:39:49.473485"
)

$labelMap = @{}
$realSessions | ForEach-Object { $labelMap[$_] = "REAL" }
$replaySessions | ForEach-Object { $labelMap[$_] = "REPLAY" }

$labeledData = @(
    $data | Where-Object { $labelMap.ContainsKey($_.session_id) } |
    ForEach-Object {
        $_ | Add-Member -NotePropertyName label -NotePropertyValue $labelMap[$_.session_id] -Force
        $_
    }
)

$cleanData = @(
    $labeledData | Where-Object {
        -not (
            [double]$_.laplacian_variance -eq 0 -and
            [double]$_.edge_density -eq 0 -and
            [double]$_.intensity_mean -eq 0 -and
            [double]$_.intensity_std -eq 0
        )
    }
)
$cleanData | Export-Csv (Join-Path $outDir "face_liveness_texture_clean.csv") -NoTypeInformation -Encoding UTF8

function Percentile([double[]]$Values,[double]$P) {
    $v=@($Values|Sort-Object)
    if($v.Count -eq 0){return [double]::NaN}
    if($v.Count -eq 1){return $v[0]}
    $pos=($v.Count-1)*$P
    $lo=[math]::Floor($pos); $hi=[math]::Ceiling($pos)
    if($lo -eq $hi){return $v[$lo]}
    return $v[$lo]+(($v[$hi]-$v[$lo])*($pos-$lo))
}

function Stats($Rows,$Feature) {
    $v=@($Rows|ForEach-Object{[double]($_.$Feature)})
    [PSCustomObject]@{
        Feature=$Feature; N=$v.Count
        Mean=[math]::Round(($v|Measure-Object -Average).Average,4)
        Median=[math]::Round((Percentile $v .50),4)
        P10=[math]::Round((Percentile $v .10),4)
        P25=[math]::Round((Percentile $v .25),4)
        P75=[math]::Round((Percentile $v .75),4)
        P90=[math]::Round((Percentile $v .90),4)
        Min=[math]::Round(($v|Measure-Object -Minimum).Minimum,4)
        Max=[math]::Round(($v|Measure-Object -Maximum).Maximum,4)
    }
}

function Eval($Rows,[double]$Threshold) {
    $tp=0;$fn=0;$tn=0;$fp=0
    foreach($r in $Rows){
        $real=([double]$r.laplacian_variance -ge $Threshold)
        if($r.label -eq "REAL"){
            if($real){$tp++}else{$fn++}
        }else{
            if($real){$fp++}else{$tn++}
        }
    }
    $rr=if(($tp+$fn)-gt 0){$tp/($tp+$fn)}else{0}
    $rp=if(($tn+$fp)-gt 0){$tn/($tn+$fp)}else{0}
    $pr=if(($tp+$fp)-gt 0){$tp/($tp+$fp)}else{0}
    $f1=if(($pr+$rr)-gt 0){2*$pr*$rr/($pr+$rr)}else{0}
    [PSCustomObject]@{
        Threshold=$Threshold
        FrameAccuracy=[math]::Round(100*($tp+$tn)/[math]::Max(1,($tp+$tn+$fp+$fn)),2)
        RecallREAL=[math]::Round(100*$rr,2)
        RecallREPLAY=[math]::Round(100*$rp,2)
        BalancedAccuracy=[math]::Round(50*($rr+$rp),2)
        PrecisionREAL=[math]::Round(100*$pr,2)
        F1REAL=[math]::Round(100*$f1,2)
        TP=$tp;FN=$fn;TN=$tn;FP=$fp
    }
}

# 4 fitur
$stats=@()
foreach($f in @("laplacian_variance","edge_density","intensity_mean","intensity_std")){
    $stats += Stats (@($cleanData|Where-Object label -eq "REAL")) $f
    $stats += Stats (@($cleanData|Where-Object label -eq "REPLAY")) $f
}
$stats | Export-Csv (Join-Path $outDir "texture_feature_statistics.csv") -NoTypeInformation -Encoding UTF8

# Sensitivity 130..200
$sensitivity=@()
for($t=130;$t -le 200;$t++){ $sensitivity += Eval $cleanData $t }
$sensitivity | Export-Csv (Join-Path $outDir "texture_threshold_sensitivity.csv") -NoTypeInformation -Encoding UTF8
$best=$sensitivity|Sort-Object @{E={[double]$_.BalancedAccuracy};Descending=$true},@{E={[double]$_.FrameAccuracy};Descending=$true}|Select-Object -First 1

# LOSO
$sessions=@($cleanData|Group-Object session_id|ForEach-Object{
    [PSCustomObject]@{Session=$_.Name;Label=$_.Group[0].label;Frames=$_.Count}
})
$loso=@()
foreach($s in $sessions){
    $train=@($cleanData|Where-Object session_id -ne $s.Session)
    $test=@($cleanData|Where-Object session_id -eq $s.Session)
    $trainScores=@()
    for($t=130;$t -le 200;$t++){$trainScores += Eval $train $t}
    $bt=$trainScores|Sort-Object @{E={[double]$_.BalancedAccuracy};Descending=$true},@{E={[double]$_.FrameAccuracy};Descending=$true}|Select-Object -First 1
    $ev=Eval $test ([double]$bt.Threshold)
    $loso += [PSCustomObject]@{
        Session=$s.Session;Label=$s.Label;Frames=$s.Frames
        BestThreshold=$bt.Threshold;FrameAccuracy=$ev.FrameAccuracy
        RecallREAL=$ev.RecallREAL;RecallREPLAY=$ev.RecallREPLAY
        BalancedAccuracy=$ev.BalancedAccuracy
        TP=$ev.TP;FN=$ev.FN;TN=$ev.TN;FP=$ev.FP
    }
}
$loso|Export-Csv (Join-Path $outDir "loso_session_results.csv") -NoTypeInformation -Encoding UTF8

$TP=($loso|Measure-Object TP -Sum).Sum
$FN=($loso|Measure-Object FN -Sum).Sum
$TN=($loso|Measure-Object TN -Sum).Sum
$FP=($loso|Measure-Object FP -Sum).Sum
$losoRR=100*$TP/($TP+$FN)
$losoRP=100*$TN/($TN+$FP)
$losoAcc=100*($TP+$TN)/($TP+$TN+$FP+$FN)
$losoBA=($losoRR+$losoRP)/2

# Error analysis threshold 163
$finalThreshold=163
$fnRows=@($cleanData|Where-Object{$_.label -eq "REAL" -and [double]$_.laplacian_variance -lt $finalThreshold})
$fpRows=@($cleanData|Where-Object{$_.label -eq "REPLAY" -and [double]$_.laplacian_variance -ge $finalThreshold})
$errorRows=@()
$fnRows|ForEach-Object{$errorRows += [PSCustomObject]@{ErrorType="FN";Session=$_.session_id;Frame=$_.frame;Laplacian=[double]$_.laplacian_variance}}
$fpRows|ForEach-Object{$errorRows += [PSCustomObject]@{ErrorType="FP";Session=$_.session_id;Frame=$_.frame;Laplacian=[double]$_.laplacian_variance}}
$errorRows|Export-Csv (Join-Path $outDir "texture_error_analysis.csv") -NoTypeInformation -Encoding UTF8

# Ringkasan
$summary=@(
"=== TEXTURE ANALYSIS SUMMARY ===",
"Dataset: face_liveness_texture_data_2026-09-29.csv",
"Raw labeled frames: $($labeledData.Count)",
"Clean frames: $($cleanData.Count)",
"Removed all-zero frames: $($labeledData.Count-$cleanData.Count)",
"REAL clean: $(@($cleanData|Where-Object label -eq 'REAL').Count)",
"REPLAY clean: $(@($cleanData|Where-Object label -eq 'REPLAY').Count)",
"",
"--- SENSITIVITY 130..200 ---",
"Best threshold: $($best.Threshold)",
"Frame Accuracy: $($best.FrameAccuracy)%",
"Recall REAL: $($best.RecallREAL)%",
"Recall REPLAY: $($best.RecallREPLAY)%",
"Balanced Accuracy: $($best.BalancedAccuracy)%",
"Precision REAL: $($best.PrecisionREAL)%",
"F1 REAL: $($best.F1REAL)%",
"TP=$($best.TP), FN=$($best.FN), TN=$($best.TN), FP=$($best.FP)",
"",
"--- LOSO ---",
"Aggregated TP=$TP, FN=$FN, TN=$TN, FP=$FP",
"Frame Accuracy: $([math]::Round($losoAcc,2))%",
"Recall REAL: $([math]::Round($losoRR,2))%",
"Recall REPLAY: $([math]::Round($losoRP,2))%",
"Balanced Accuracy: $([math]::Round($losoBA,2))%",
"",
"--- ERROR ANALYSIS THRESHOLD 163 ---",
"FN: $($fnRows.Count) / 1766 = $([math]::Round(100*$fnRows.Count/1766,2))%",
"FP: $($fpRows.Count) / 1458 = $([math]::Round(100*$fpRows.Count/1458,2))%",
"",
"CATATAN: LOSO dan sensitivity all-clean-frame adalah dua protokol berbeda.",
"Threshold 163 adalah hasil eksperimen pada 20 session ini, bukan klaim universal."
)
$summary|Set-Content (Join-Path $outDir "texture_analysis_summary.txt") -Encoding UTF8

Write-Host ""
Write-Host "ANALISIS SELESAI"
Write-Host "Folder hasil: $outDir"
Write-Host "Threshold sensitivity terbaik: $($best.Threshold)"
Write-Host "LOSO Frame Accuracy: $([math]::Round($losoAcc,2))%"
Write-Host "LOSO Balanced Accuracy: $([math]::Round($losoBA,2))%"
