$comparisonRoot = $PSScriptRoot
$trialRoot = Split-Path -Parent $comparisonRoot
$writingRoot = Split-Path -Parent $trialRoot
$common = Join-Path $comparisonRoot 'packets'
New-Item -ItemType Directory -Path $common -Force | Out-Null
$outputRule = 'Return Markdown with exactly these headings: Purpose, Sequence, First draft, Review, Final paragraph. Purpose is one sentence. Sequence is up to five short editorial bullets. Review lists specific findings and edits after rereading the two neighbors and your first draft. If nothing changes, say so honestly. Include final sentence prose-comma counts. Do not give yourself a score. Do not claim author approval. Do not wrap the response in a code fence. Return the complete response directly. The host saves it.'
$manifest = @()
foreach ($spec in @(@{case='primary'; n=3},@{case='system';n=2})) {
    for ($rep = 1; $rep -le $spec.n; $rep++) {
        $id = '{0}_{1:d2}' -f $spec.case,$rep
        $baseline = 'v3_{0}_{1:d2}' -f $spec.case,$rep
        $packet = Get-Content -Raw -LiteralPath (Join-Path $trialRoot "runs\$baseline\packet.json") | ConvertFrom-Json
        $packet.PSObject.Properties.Remove('output_path')
        $packet.isolation = 'Use only the contents of this packet. Do not read referenced files or other drafts, browse, or consult another agent. The original target and other trials are withheld.'
        $packet.output = $outputRule + ' First draft and Final paragraph are each one prose paragraph.'
        $packet | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $common "$id.json") -Encoding utf8
        $manifest += [ordered]@{id=$id; case=$spec.case; replicate=$rep; packet="packets/$id.json"; astra_baseline="../runs/$baseline/response.md"; claude_response="claude/$id/response.md"}
    }
}
$draft = Get-Content -Raw -LiteralPath (Join-Path $writingRoot 'manuscript2_journal_draft.json') | ConvertFrom-Json
$textBlocks = @([regex]::Matches($draft.html,'(?s)<p\b[^>]*>(.*?)</p>') | ForEach-Object { [Net.WebUtility]::HtmlDecode([regex]::Replace($_.Groups[1].Value,'<[^>]+>','')) })
$previous = $textBlocks | Where-Object { $_ -like 'The normalized coprime factor online stability indicator*' } | Select-Object -First 1
$next = $textBlocks | Where-Object { $_ -like 'The estimator monitors the outer controller loop*' } | Select-Object -First 1
$paper2 = [ordered]@{
    task = 'Write an improved engineering-journal passage for Paper 2 introducing Figure 1 and the control signals before the loop transfer functions. Write one or two connected paragraphs. Improve the concepts, sequence, and reader-facing message while preserving the facts below. The original target passage and any previous revisions are withheld.'
    isolation = 'Use only this packet. Do not read referenced files or other drafts, browse, or consult another agent. Use required_ideas as the authority if shorthand in a neighboring draft is inconsistent.'
    paper_scope = 'Paper 2. Use hybrid simulation, experiment, initial, and adaptive factor. Do not use RTHS or whose. Do not add the Paper 1 controller-switching intervention. The surrounding section already introduces degradation and the estimator. The next passage defines the outer controller loop equations. Avoid re-explaining the full degradation mechanism here.'
    writing_guide = Get-Content -Raw -LiteralPath (Join-Path $trialRoot 'versions\v3\write.md')
    scientific_expressions = Get-Content -Raw -LiteralPath (Join-Path $trialRoot 'versions\v3\scientific_expressions.md')
    previous_paragraph = $previous
    required_ideas = @(
        'Figure 1 presents the hybrid simulation with the adaptive controller. Give the figure an engineering purpose rather than telling the reader to locate a loop. Use established names, not vague replacements such as control arrangement.',
        'The numerical substructure computes desired displacement d(t) from ground acceleration and measured force f_m(t).',
        'A phase-lead compensator advances d(t) to produce reference u(t). It is designed to offset transfer-system lag and improve tracking. It acts on the reference outside the outer controller loop.',
        'The outer controller C(s) acts on tracking error u(t)-y(t). y(t) is the measured actuator displacement.',
        'The adaptive factor lambda in (0,1] scales the controller output to produce command v(t) applied to plant H(s,k). The prior paragraph already links the estimated indicator to adjustment of lambda.',
        'H(s,k) comprises the transfer system and the specimen of stiffness k. In Paper 2 the transfer system includes the inner-loop controller, servo-valve, actuator, and control-structure interaction between actuator and specimen. Account for all four across clear sentences. Interaction is a physical coupling, not another piece of hardware.',
        'The measured displacement y(t) closes the outer controller loop. The measured force f_m(t) returns to the numerical substructure and closes the numerical substructure loop. Keep these loops distinct.',
        'Do not assert perfect tracking, guaranteed stability, or new scientific results. Preserve notation d(t), u(t), y(t), v(t), C(s), H(s,k), k, lambda, and f_m(t). Use readable inline mathematical notation.'
    )
    next_paragraph = $next
    output = $outputRule + ' First draft and Final paragraph may each contain one or two connected prose paragraphs. Keep the focus on the Figure 1 explanation.'
}
for ($rep = 1; $rep -le 3; $rep++) {
    $id = 'paper2_{0:d2}' -f $rep
    $paper2 | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $common "$id.json") -Encoding utf8
    $manifest += [ordered]@{id=$id; case='paper2'; replicate=$rep; packet="packets/$id.json"; astra_baseline="astra/$id/response.md"; claude_response="claude/$id/response.md"}
    New-Item -ItemType Directory -Path (Join-Path $comparisonRoot "astra\$id") -Force | Out-Null
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $comparisonRoot 'manifest.json') -Encoding utf8
foreach ($run in $manifest) {
    $packetText = Get-Content -Raw -LiteralPath (Join-Path $comparisonRoot $run.packet)
    $prompt = "You are an independent engineering manuscript writer. No conversation history or earlier trial is supplied. Follow this task packet and return only the requested Markdown response.`n`n$packetText"
    $prompt | Set-Content -LiteralPath (Join-Path $common "$($run.id).txt") -Encoding utf8
}
Write-Output "Prepared $($manifest.Count) Claude tasks and three fresh paired Codex tasks."
