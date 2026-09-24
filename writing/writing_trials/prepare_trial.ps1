param(
    [Parameter(Mandatory=$true)][string]$Version,
    [ValidateSet('primary','transfer','system')][string]$Case = 'primary',
    [int]$Replicates = 3
)
$trialRoot = $PSScriptRoot
$writingRoot = Split-Path -Parent $trialRoot
$versionRoot = Join-Path $trialRoot "versions\$Version"
New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
foreach ($name in @('write.md','scientific_expressions.md')) {
    $snapshot = Join-Path $versionRoot $name
    if (-not (Test-Path -LiteralPath $snapshot)) {
        Copy-Item -LiteralPath (Join-Path $writingRoot $name) -Destination $snapshot
    }
}
$paragraphs = Get-Content -Raw -LiteralPath (Join-Path $trialRoot 'paper1_paragraphs.json') | ConvertFrom-Json
if ($Case -eq 'primary') {
    $targetId = 56
    $points = @(
        'Explain a mechanism suggested by laboratory observations. Do not claim that the paper experimentally validates an indicator or intervention.',
        'The controller is initially tuned to overcome the relatively high specimen stiffness and meet the required tracking performance.',
        'Stiffness loss makes the specimen easier to move. Keeping the same corrective control action is likely to cause more overshoot and a larger displacement response relative to the initial stiffness condition.',
        'Specimen mass influences the extent of response amplification. No direction or numerical dependence is specified.',
        'The interaction between the degraded specimen and transfer system including the controller can eventually drive the system toward instability.',
        'The behavior is not universal. The dominant instability mechanism and stability-indicator performance can vary substantially with both transfer-system and specimen dynamics.'
    )
} elseif ($Case -eq 'transfer') {
    $targetId = 52
    $points = @(
        'Structural degradation is nonlinear and time varying.',
        'Use a short-window linear approximation to keep the analysis tractable and suitable for online evaluation.',
        'The approximation may be inaccurate during brief intervals of rapid property change.',
        'It is typically accurate before and after those events and during slowly evolving degradation. Preserve this qualification without claiming a guarantee.',
        'Do not add algorithms, stiffness estimation methods, sampling choices, or experimental evidence.'
    )
} else {
    $targetId = 22
    $points = @(
        'RTHS partitions a reference structural model into a numerical substructure and a physical substructure.',
        'The numerical substructure is evaluated in real time on a computer. Actuators excite the physical substructure and sensors instrument it.',
        'The transfer system comprises the controller, servo-valve, and actuator hydraulics. It enforces interface compatibility and equilibrium by synchronizing the physical response with the numerically computed response. Preserve these functions without adding new components from another paper.',
        'Figure 1 shows a typical RTHS scheme. The numerical substructure receives ground acceleration a_g(t) and computes desired displacement d_d. The physical substructure provides measured force f_e.',
        'Figure 2 gives a closer view of the transfer system.',
        'Seismic excitation is an illustration. The proposed framework also applies to other external excitations such as wind loading when the corresponding input to the numerical substructure is changed.',
        'Use Figure 1 and Figure 2 exactly. Keep the Paper 1 symbols a_g(t), d_d, and f_e. Do not introduce Paper 2 symbols or interventions.'
    )
}
$previousId = if ($Case -eq 'system') { 20 } else { $targetId - 1 }
$followingId = if ($Case -eq 'system') { 27 } else { $targetId + 1 }
$previous = ($paragraphs | Where-Object id -eq $previousId).text
$following = ($paragraphs | Where-Object id -eq $followingId).text
if ($Case -eq 'system') { $previous += "`nThe missing paragraph opens Section 2: Problem Formulation. Figure 1 and Figure 2 and their captions appear after it and before the next prose paragraph." }
$dictionary = Get-Content -Raw -LiteralPath (Join-Path $versionRoot 'scientific_expressions.md')
$guide = Get-Content -Raw -LiteralPath (Join-Path $versionRoot 'write.md')
for ($replicate = 1; $replicate -le $Replicates; $replicate++) {
    $id = '{0}_{1}_{2:d2}' -f $Version,$Case,$replicate
    $runRoot = Join-Path $trialRoot "runs\$id"
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
    $packet = [ordered]@{
        task = 'Write one missing engineering journal paragraph for Paper 1 from the supplied ideas and surrounding paragraphs. The original target paragraph is intentionally withheld. Preserve the content rather than trying to recover its wording.'
        isolation = 'Read this packet only. Do not read the source manuscript, other packets, previous trials, repository writing guides, or referenced files. Do not browse or use other agents. You may use a shell to read this packet and save your response only.'
        paper_scope = 'This is Paper 1. It uses RTHS and controller switching. Do not introduce Paper 2, the adaptive factor lambda, or Paper 2 estimator branches. No new scientific claims or citations are needed.'
        writing_guide = $guide
        scientific_expressions = $dictionary
        previous_paragraph = $previous
        required_ideas = $points
        next_paragraph = $following
        output = 'Save a Markdown response at the supplied output path. Use these exact headings: Purpose, Sequence, First draft, Review, Final paragraph. Purpose is one sentence. Sequence is up to five short editorial bullets. First draft and Final paragraph are each one prose paragraph. Review lists specific findings and edits after rereading the two neighbors and your first draft. If nothing changes, say so honestly. Do not include a score or claims that the author approves the draft. Finish by reporting the output path.'
        output_path = Join-Path $runRoot 'response.md'
    }
    $packet | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runRoot 'packet.json') -Encoding utf8
    Write-Output (Join-Path $runRoot 'packet.json')
}
