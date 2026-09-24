$trialRoot = $PSScriptRoot
$paragraphs = Get-Content -Raw -LiteralPath (Join-Path $trialRoot 'paper1_paragraphs.json') | ConvertFrom-Json
function Get-SectionParagraph([string]$response,[string]$heading) {
    $content = [regex]::Match($response,"(?ms)^#{1,6}\s+$heading\s*\r?\n(.*?)(?=^#{1,6}\s|\z)").Groups[1].Value.Trim()
    return ([regex]::Split($content,'\r?\n\s*\r?\n'))[0].Trim()
}
function Measure-Paragraph([string]$paragraph) {
    $sentences = [regex]::Split($paragraph,'(?<=[.!?])\s+(?=[A-Z])')
    $counts = @($sentences | ForEach-Object { ([regex]::Matches($_,',')).Count })
    return [ordered]@{
        words = ([regex]::Matches($paragraph,"\b[\p{L}\p{N}]+(?:[-’'][\p{L}\p{N}]+)*\b")).Count
        sentences = $sentences.Count
        commas_per_sentence = $counts
        max_commas = ($counts | Measure-Object -Maximum).Maximum
        semicolons = ([regex]::Matches($paragraph,';')).Count
        whose = ([regex]::Matches($paragraph,'\bwhose\b','IgnoreCase')).Count
        sensors_instrument_it = [bool]($paragraph -match '\bsensors instrument it\b')
    }
}
$records = foreach ($run in (Get-ChildItem -LiteralPath (Join-Path $trialRoot 'runs') -Directory | Sort-Object Name)) {
    $responsePath = Join-Path $run.FullName 'response.md'
    if (-not (Test-Path -LiteralPath $responsePath)) { continue }
    $packet = Get-Content -Raw -LiteralPath (Join-Path $run.FullName 'packet.json') | ConvertFrom-Json
    $response = Get-Content -Raw -LiteralPath $responsePath
    $first = Get-SectionParagraph $response 'First draft'
    $final = Get-SectionParagraph $response 'Final paragraph'
    $parts = $run.Name -split '_'
    $targetId = switch ($parts[1]) { primary {56} transfer {52} system {22} }
    $reference = ($paragraphs | Where-Object id -eq $targetId).text
    $snapshotGuide = Get-Content -Raw -LiteralPath (Join-Path $trialRoot "versions\$($parts[0])\write.md")
    $snapshotDictionary = Get-Content -Raw -LiteralPath (Join-Path $trialRoot "versions\$($parts[0])\scientific_expressions.md")
    [ordered]@{
        run = $run.Name
        version = $parts[0]
        case = $parts[1]
        guide_matches_snapshot = ($packet.writing_guide -ceq $snapshotGuide)
        dictionary_matches_snapshot = ($packet.scientific_expressions -ceq $snapshotDictionary)
        full_target_leaked = ((@($packet.writing_guide,$packet.scientific_expressions,$packet.previous_paragraph,($packet.required_ideas -join "`n"),$packet.next_paragraph) -join "`n").Contains($reference.Trim()))
        first = Measure-Paragraph $first
        final = Measure-Paragraph $final
        review_changed_draft = ($first -cne $final)
    }
}
$checks = foreach ($caseName in @('primary','transfer','system')) {
    $packets = @(Get-ChildItem -LiteralPath (Join-Path $trialRoot 'runs') -Directory | Where-Object Name -like "*_${caseName}_*" | ForEach-Object { Get-Content -Raw -LiteralPath (Join-Path $_.FullName 'packet.json') | ConvertFrom-Json })
    $uniqueInputs = @($packets | ForEach-Object { [ordered]@{ previous=$_.previous_paragraph; ideas=$_.required_ideas; next=$_.next_paragraph } | ConvertTo-Json -Depth 6 -Compress } | Sort-Object -Unique)
    [ordered]@{ case=$caseName; packets=$packets.Count; distinct_fact_and_neighbor_inputs=$uniqueInputs.Count }
}
[ordered]@{ records=@($records); input_checks=@($checks) } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $trialRoot 'mechanical_summary.json') -Encoding utf8
$records | ForEach-Object { '{0}: {1} words, {2} sentences, max commas {3}, awkward sensor phrase {4}, review changed {5}' -f $_.run,$_.final.words,$_.final.sentences,$_.final.max_commas,$_.final.sensors_instrument_it,$_.review_changed_draft }
$checks | ConvertTo-Json -Depth 5
