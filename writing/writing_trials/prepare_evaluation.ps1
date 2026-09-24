param(
    [Parameter(Mandatory=$true)][string]$Version,
    [ValidateSet('primary','transfer','system')][string]$Case = 'primary'
)
$trialRoot = $PSScriptRoot
$paragraphs = Get-Content -Raw -LiteralPath (Join-Path $trialRoot 'paper1_paragraphs.json') | ConvertFrom-Json
$targetId = switch ($Case) { primary {56} transfer {52} system {22} }
$runs = Get-ChildItem -LiteralPath (Join-Path $trialRoot 'runs') -Directory | Where-Object Name -like "${Version}_${Case}_*" | Sort-Object Name -Descending
$candidates = @()
$mapping = @()
$position = 0
foreach ($run in $runs) {
    $response = Get-Content -Raw -LiteralPath (Join-Path $run.FullName 'response.md')
    $final = [regex]::Match($response,'(?ms)^#{1,6}\s+Final paragraph\s*\r?\n(.*?)(?=^#{1,6}\s|\z)').Groups[1].Value.Trim()
    $final = ([regex]::Split($final,'\r?\n\s*\r?\n'))[0].Trim()
    if (-not $final) { throw "Final paragraph heading missing in $($run.Name)" }
    $sentences = [regex]::Split($final,'(?<=[.!?])\s+(?=[A-Z])')
    $metrics = [ordered]@{
        words = ([regex]::Matches($final,"\b[\p{L}\p{N}]+(?:[-’'][\p{L}\p{N}]+)*\b")).Count
        sentences = $sentences.Count
        commas_per_sentence = @($sentences | ForEach-Object { ([regex]::Matches($_,',')).Count })
        semicolons = ([regex]::Matches($final,';')).Count
        whose = ([regex]::Matches($final,'\bwhose\b','IgnoreCase')).Count
    }
    $label = [string][char](65 + $position)
    $position++
    $candidates += [ordered]@{ label=$label; paragraph=$final; metrics=$metrics }
    $mapping += [ordered]@{label=$label; run=$run.Name; metrics=$metrics}
}
$packet = [ordered]@{
    task = 'Independently evaluate candidate paragraphs against the actual Paper 1 paragraph and fixed criteria. You have no prior trial context. Read only this packet and write the requested review file. Do not read source files, guide versions, prior reviews, or candidate folders. Do not browse or spawn agents.'
    source_note = 'Actual reference text is extracted from the author-provided Paper 1 DOCX. It is the authority for intended meaning, not a style template. Mathematical text in neighbors is flattened. Do not penalize clearer wording or different sentence order when the meaning and flow are preserved.'
    previous_paragraph = (Get-Content -Raw -LiteralPath (Join-Path $runs[0].FullName 'packet.json') | ConvertFrom-Json).previous_paragraph
    actual_paragraph = ($paragraphs | Where-Object id -eq $targetId).text
    next_paragraph = (Get-Content -Raw -LiteralPath (Join-Path $runs[0].FullName 'packet.json') | ConvertFrom-Json).next_paragraph
    required_ideas = (Get-Content -Raw -LiteralPath (Join-Path $runs[0].FullName 'packet.json') | ConvertFrom-Json).required_ideas
    criteria = @(
        'Completeness 0–2: 2 retains all required ideas, 1 weakens or partly omits one, 0 loses a major point or multiple points.',
        'Fidelity 0–2: 2 preserves causal relationships and qualifications with no added claim, 1 has one ambiguous relation or slightly stronger assertion, 0 invents a mechanism or materially changes meaning.',
        'Context and sequence 0–2: 2 gives a clear progression between neighbors, 1 has local repetition or a weak transition, 0 has misplaced purpose or broken reasoning.',
        'Terminology 0–2: 2 uses precise established language and clear referents, 1 has one vague label or gratuitous synonym, 0 misnames a physical or control concept.',
        'Readability 0–2: 2 has clear connected sentences without crowded clauses, 1 has one awkward or overloaded sentence, 0 has repeated difficult sentences.',
        'Acceptance requires total >=9 with completeness=2 and fidelity=2. No semicolon or whose. Flag every sentence with 3 or more prose commas unless a specific readability justification resolves it.',
        'Treat ordinary English as ordinary English. Do not invent a defect simply because wording differs. Do not demand sentence-for-sentence copying. The final caveat must retain its true scope. No paper-2 adaptive factor may be introduced.'
    )
    candidates = $candidates
    output = 'Write Markdown at output_path. For each candidate include a 5-dimension score table, total, acceptance decision, and concrete comparisons with the actual paragraph. Quote the exact candidate wording for every deduction. Distinguish material errors from optional stylistic preferences. End with recurring problems and any limits of your assessment. Also report whether all candidates were assessed. Do not rewrite the candidates.'
    output_path = Join-Path $trialRoot "evaluation_${Version}_${Case}.md"
}
if ($Version -eq 'v3') {
    $packet.criteria += 'Version 3 acceptance gate: completeness, fidelity, and terminology must EACH equal 2. An unresolved technical-name defect cannot be offset by other scores. Every sentence must have fewer than 3 prose commas. Reject identified awkward subject/verb assignments that distort the physical role. Ordinary English differences and optional preferences are not terminology defects.'
}
$packet | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $trialRoot "evaluation_${Version}_${Case}.json") -Encoding utf8
$mapping | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $trialRoot "mapping_${Version}_${Case}.json") -Encoding utf8
Write-Output (Join-Path $trialRoot "evaluation_${Version}_${Case}.json")
$mapping | ConvertTo-Json -Depth 8
