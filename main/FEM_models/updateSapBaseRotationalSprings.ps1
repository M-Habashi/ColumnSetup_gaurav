param(
    [Parameter(Mandatory = $true)]
    [string]$ModelPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseRotationKText
)

$ErrorActionPreference = 'Stop'

$apiPath = 'C:\Program Files\Computers and Structures\SAP2000 26\CSiAPIv1.dll'
if (-not (Test-Path -LiteralPath $apiPath -PathType Leaf)) {
    throw "SAP2000 API assembly not found: $apiPath"
}

$resolvedModelPath = (Resolve-Path -LiteralPath $ModelPath).Path
$baseRotationK = [double]::Parse(
    $BaseRotationKText,
    [Globalization.CultureInfo]::InvariantCulture)
if ([double]::IsNaN($baseRotationK) -or `
    [double]::IsInfinity($baseRotationK) -or $baseRotationK -le 0) {
    throw 'BaseRotationKText must represent a positive finite number.'
}

Add-Type -Path $apiPath
$sapProcesses = @(
    Get-Process -Name 'SAP2000' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 }
)
if ($sapProcesses.Count -eq 0) {
    throw 'No visible SAP2000 instance is open. Open SAP2000 and rerun build_ref_model.m.'
}
if ($sapProcesses.Count -gt 1) {
    throw 'More than one visible SAP2000 instance is open. Keep one instance open and rerun build_ref_model.m.'
}

[CSiAPIv1.cHelper]$helper = [CSiAPIv1.Helper]::new()
$application = $helper.GetObjectProcess(
    'CSI.SAP2000.API.SapObject',
    $sapProcesses[0].Id)
if ($null -eq $application) {
    throw 'Could not attach to the visible SAP2000 instance.'
}

$model = $application.SapModel
$openResult = $model.File.OpenFile($resolvedModelPath)
if ($openResult -ne 0) {
    throw "SAP2000 failed to open the copied model (return code $openResult)."
}

$unitsResult = $model.SetPresentUnits([CSiAPIv1.eUnits]::N_mm_C)
if ($unitsResult -ne 0) {
    throw "SAP2000 failed to set N-mm-C units (return code $unitsResult)."
}
if ($model.GetModelIsLocked()) {
    $unlockResult = $model.SetModelIsLocked($false)
    if ($unlockResult -ne 0) {
        throw "SAP2000 failed to unlock the model (return code $unlockResult)."
    }
}

$baseJoints = @('J_L0_G0', 'J_L0_G1', 'J_L0_G2', 'J_L0_G3')
[double[]]$springTemplate = @(0, 0, 0, 0, $baseRotationK, 0)
foreach ($joint in $baseJoints) {
    [double[]]$spring = $springTemplate.Clone()
    $setResult = $model.PointObj.SetSpring(
        $joint,
        [ref]$spring,
        [CSiAPIv1.eItemType]::Objects,
        $false,
        $true)
    if ($setResult -ne 0) {
        throw "Failed to set the base spring at $joint (return code $setResult)."
    }

    [double[]]$verifiedSpring = $null
    $getResult = $model.PointObj.GetSpring($joint, [ref]$verifiedSpring)
    if ($getResult -ne 0 -or $verifiedSpring.Length -ne 6) {
        throw "Failed to verify the base spring at $joint."
    }
    $tolerance = 1e-12 * [Math]::Max(1.0, [Math]::Abs($baseRotationK))
    if ([Math]::Abs($verifiedSpring[4] - $baseRotationK) -gt $tolerance) {
        throw "Base spring verification failed at $joint."
    }
}

$saveResult = $model.File.Save($resolvedModelPath)
if ($saveResult -ne 0) {
    throw "SAP2000 failed to save the specimen model (return code $saveResult)."
}

Write-Output ('Updated {0} base joints to R2 = {1:R} N*mm/rad.' -f `
    $baseJoints.Count, $baseRotationK)
Write-Output ('Saved SAP model: {0}' -f $resolvedModelPath)
