param(
    [Parameter(Mandatory = $true)]
    [string]$TemplatePath,

    [Parameter(Mandatory = $true)]
    [string]$ModelPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseRotationKText,

    [Parameter(Mandatory = $true)]
    [string]$StoryHeightText,

    [Parameter(Mandatory = $true)]
    [string]$ExperimentalHeightText,

    [Parameter(Mandatory = $true)]
    [string]$FloorForcesText
)

$ErrorActionPreference = 'Stop'

$apiPath = 'C:\Program Files\Computers and Structures\SAP2000 26\CSiAPIv1.dll'
if (-not (Test-Path -LiteralPath $apiPath -PathType Leaf)) {
    throw "SAP2000 API assembly not found: $apiPath"
}

$resolvedTemplatePath = (Resolve-Path -LiteralPath $TemplatePath).Path
$resolvedModelPath = [IO.Path]::GetFullPath($ModelPath)
$baseRotationK = [double]::Parse(
    $BaseRotationKText,
    [Globalization.CultureInfo]::InvariantCulture)
if ([double]::IsNaN($baseRotationK) -or `
    [double]::IsInfinity($baseRotationK) -or $baseRotationK -le 0) {
    throw 'BaseRotationKText must represent a positive finite number.'
}
$storyHeight = [double]::Parse(
    $StoryHeightText,
    [Globalization.CultureInfo]::InvariantCulture)
$experimentalHeight = [double]::Parse(
    $ExperimentalHeightText,
    [Globalization.CultureInfo]::InvariantCulture)
if ($storyHeight -le $experimentalHeight -or $experimentalHeight -le 0) {
    throw 'Story height must exceed the positive experimental height.'
}
[double[]]$floorForces = @(
    $FloorForcesText.Split(',') | ForEach-Object {
        [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
    }
)
if ($floorForces.Count -ne 3) {
    throw 'FloorForcesText must contain three comma-separated values.'
}

Add-Type -Path $apiPath
[CSiAPIv1.cHelper]$helper = [CSiAPIv1.Helper]::new()
[CSiAPIv1.cOAPI]$application = $null
$sapProcesses = @(
    Get-Process -Name 'SAP2000' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 }
)
if ($sapProcesses.Count -eq 0) {
    $application = $helper.CreateObjectProgID(
        'CSI.SAP2000.API.SapObject')
    if ($null -eq $application) {
        throw 'Could not create a SAP2000 API application object.'
    }
    $startMethod = [CSiAPIv1.cOAPI].GetMethods() |
        Where-Object {
            $_.Name -eq 'ApplicationStart' -and
            $_.GetParameters().Count -eq 3
        } |
        Select-Object -First 1
    if ($null -eq $startMethod) {
        throw 'Could not locate the SAP2000 ApplicationStart API method.'
    }
    $startArguments = [object[]]@(
        [CSiAPIv1.eUnits]::N_mm_C,
        [bool]$true,
        [string]''
    )
    $startResult = $startMethod.Invoke($application, $startArguments)
    if ($startResult -ne 0) {
        throw "SAP2000 failed to start (return code $startResult)."
    }
    Write-Output 'SAP stage: automatically started an API instance.'
}
elseif ($sapProcesses.Count -gt 1) {
    throw 'More than one visible SAP2000 instance is open. Keep one instance open and rerun build_fem.m.'
}
else {
    $sapProcessInfo = Get-CimInstance Win32_Process -Filter `
        "ProcessId = $($sapProcesses[0].Id)"
    if ($sapProcessInfo.CommandLine -notmatch '(^|\s)/A(\s|$)') {
        throw ('The visible SAP2000 instance was not API-launched. ' +
            'Close it and rerun build_fem.m; the script will start SAP automatically.')
    }
    $application = $helper.GetObjectProcess(
        'CSI.SAP2000.API.SapObject',
        $sapProcesses[0].Id)
    if ($null -eq $application) {
        throw 'Could not attach to the visible SAP2000 API instance.'
    }
    Write-Output 'SAP stage: reused the visible API instance.'
}

$model = $application.SapModel
$templateOpenResult = $model.File.OpenFile($resolvedTemplatePath)
if ($templateOpenResult -ne 0) {
    throw "SAP2000 failed to release the target and open the template (return code $templateOpenResult)."
}

# Remove analysis files belonging to an older version of the generated
# model. If retained beside the replaced SDB, SAP opens a compatibility
# dialog and blocks unattended API execution.
$modelDirectory = [IO.Path]::GetDirectoryName($resolvedModelPath)
$modelBaseName = [IO.Path]::GetFileNameWithoutExtension($resolvedModelPath)
Get-ChildItem -LiteralPath $modelDirectory -Filter "$modelBaseName.*" |
    Where-Object {
        -not [IO.Path]::GetFullPath($_.FullName).Equals(
            $resolvedModelPath,
            [StringComparison]::OrdinalIgnoreCase)
    } |
    Remove-Item -Force
Copy-Item -LiteralPath $resolvedTemplatePath `
    -Destination $resolvedModelPath -Force
$openResult = $model.File.OpenFile($resolvedModelPath)
if ($openResult -ne 0) {
    throw "SAP2000 failed to open the copied model (return code $openResult)."
}
Write-Output 'SAP stage: copied and opened the specimen model.'

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

# Keep the experimental interface at 40 in while moving every floor to a
# common optimized story height.
$targetCoordinates = @{}
for ($level = 1; $level -le 3; $level++) {
    for ($grid = 0; $grid -le 3; $grid++) {
        $targetCoordinates[('J_L{0}_G{1}' -f $level, $grid)] = `
            $level * $storyHeight
    }
}
$targetCoordinates['J_INTERFACE'] = $experimentalHeight
foreach ($entry in $targetCoordinates.GetEnumerator()) {
    [double]$x = 0
    [double]$y = 0
    [double]$z = 0
    $coordinateResult = $model.PointObj.GetCoordCartesian(
        $entry.Key, [ref]$x, [ref]$y, [ref]$z, 'GLOBAL')
    if ($coordinateResult -ne 0) {
        throw "Failed to read coordinates for $($entry.Key)."
    }
    $changeResult = $model.EditPoint.ChangeCoordinates(
        $entry.Key, $x, $y, [double]$entry.Value)
    if ($changeResult -ne 0) {
        throw "Failed to update coordinates for $($entry.Key)."
    }
}
Write-Output 'SAP stage: updated and verified floor coordinates.'

# Verify the floor and interface elevations before changing any loads.
foreach ($entry in $targetCoordinates.GetEnumerator()) {
    [double]$x = 0
    [double]$y = 0
    [double]$z = 0
    $coordinateResult = $model.PointObj.GetCoordCartesian(
        $entry.Key, [ref]$x, [ref]$y, [ref]$z, 'GLOBAL')
    if ($coordinateResult -ne 0 -or `
        [Math]::Abs($z - [double]$entry.Value) -gt 1e-6) {
        throw "Coordinate verification failed for $($entry.Key)."
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
Write-Output 'SAP stage: updated and verified base springs.'

# Create a self-contained static case containing the normalized first-mode
# equivalent lateral forces. Each resultant is applied at one joint in the
# corresponding rigidly constrained floor translation.
$modalPattern = 'MODE1_EQ'
[void]$model.LoadPatterns.Delete($modalPattern)
$patternResult = $model.LoadPatterns.Add(
    $modalPattern,
    [CSiAPIv1.eLoadPatternType]::Other,
    0.0,
    $true)
if ($patternResult -ne 0) {
    throw "Failed to create load pattern $modalPattern."
}
for ($level = 1; $level -le 3; $level++) {
    [double]$floorForce = $floorForces[$level - 1]
    [double[]]$jointLoad = @($floorForce, 0, 0, 0, 0, 0)
    $jointName = 'J_L{0}_G0' -f $level
    $loadResult = $model.PointObj.SetLoadForce(
        $jointName,
        $modalPattern,
        [ref]$jointLoad,
        $true,
        'GLOBAL',
        [CSiAPIv1.eItemType]::Objects)
    if ($loadResult -ne 0) {
        throw "Failed to assign $modalPattern at $jointName."
    }
}

# Read every floor-joint assignment back. The complete resultant for each
# floor must exist only at G0; the other rigid-floor joints must carry none.
for ($level = 1; $level -le 3; $level++) {
    for ($grid = 0; $grid -le 3; $grid++) {
        $jointName = 'J_L{0}_G{1}' -f $level, $grid
        [int]$numberLoads = 0
        [string[]]$pointNames = $null
        [string[]]$loadPatterns = $null
        [int[]]$loadSteps = $null
        [string[]]$coordinateSystems = $null
        [double[]]$force1 = $null
        [double[]]$force2 = $null
        [double[]]$force3 = $null
        [double[]]$moment1 = $null
        [double[]]$moment2Loads = $null
        [double[]]$moment3Loads = $null
        $getLoadResult = $model.PointObj.GetLoadForce(
            $jointName,
            [ref]$numberLoads,
            [ref]$pointNames,
            [ref]$loadPatterns,
            [ref]$loadSteps,
            [ref]$coordinateSystems,
            [ref]$force1,
            [ref]$force2,
            [ref]$force3,
            [ref]$moment1,
            [ref]$moment2Loads,
            [ref]$moment3Loads,
            [CSiAPIv1.eItemType]::Objects)
        if ($getLoadResult -ne 0) {
            throw "Failed to verify joint loads at $jointName."
        }

        [double]$assignedForce = 0
        for ($loadId = 0; $loadId -lt $numberLoads; $loadId++) {
            if ($loadPatterns[$loadId] -eq $modalPattern) {
                $assignedForce += $force1[$loadId]
            }
        }
        [double]$expectedForce = 0
        if ($grid -eq 0) {
            $expectedForce = $floorForces[$level - 1]
        }
        $loadTolerance = 1e-10 * [Math]::Max(1.0, [Math]::Abs($expectedForce))
        if ([Math]::Abs($assignedForce - $expectedForce) -gt $loadTolerance) {
            throw "First-mode load verification failed at $jointName."
        }
    }
}
Write-Output 'SAP stage: assigned and verified first-mode floor forces.'

$saveResult = $model.File.Save($resolvedModelPath)
if ($saveResult -ne 0) {
    throw "SAP2000 failed to save the specimen model (return code $saveResult)."
}
Write-Output 'SAP stage: saved the edited specimen model.'

# Solve the first-mode equivalent static case and verify the moment at the
# top of the lower experimental-column segment.
[void]$model.Analyze.SetRunCaseFlag('', $false, $true)
$caseFlagResult = $model.Analyze.SetRunCaseFlag(
    $modalPattern, $true, $false)
if ($caseFlagResult -ne 0) {
    throw "Failed to select $modalPattern for analysis."
}
$analysisResult = $model.Analyze.RunAnalysis()
if ($analysisResult -ne 0) {
    throw "SAP2000 analysis failed (return code $analysisResult)."
}
Write-Output 'SAP stage: completed the equivalent-force analysis.'
[void]$model.Results.Setup.DeselectAllCasesAndCombosForOutput()
[void]$model.Results.Setup.SetCaseSelectedForOutput($modalPattern, $true)

[int]$numberResults = 0
[string[]]$objectNames = $null
[double[]]$objectStations = $null
[string[]]$elementNames = $null
[double[]]$elementStations = $null
[string[]]$loadCases = $null
[string[]]$stepTypes = $null
[double[]]$stepNumbers = $null
[double[]]$axialForces = $null
[double[]]$shear2 = $null
[double[]]$shear3 = $null
[double[]]$torsion = $null
[double[]]$moment2 = $null
[double[]]$moment3 = $null
$forceResult = $model.Results.FrameForce(
    'C_G0_S1_LOWER_EXP',
    [CSiAPIv1.eItemTypeElm]::ObjectElm,
    [ref]$numberResults,
    [ref]$objectNames,
    [ref]$objectStations,
    [ref]$elementNames,
    [ref]$elementStations,
    [ref]$loadCases,
    [ref]$stepTypes,
    [ref]$stepNumbers,
    [ref]$axialForces,
    [ref]$shear2,
    [ref]$shear3,
    [ref]$torsion,
    [ref]$moment2,
    [ref]$moment3)
if ($forceResult -ne 0 -or $numberResults -eq 0) {
    throw 'Failed to read experimental-column forces from SAP2000.'
}

$caseIndices = @(0..($numberResults-1) | Where-Object {
    $loadCases[$_] -eq $modalPattern
})
if ($caseIndices.Count -eq 0) {
    throw "No frame-force results were returned for $modalPattern."
}
$interfaceIndex = $caseIndices | Sort-Object {
    $objectStations[$_]
} -Descending | Select-Object -First 1
$sapInterfaceMoment = $moment3[$interfaceIndex]
$momentScale = 1.0
foreach ($index in $caseIndices) {
    $momentScale = [Math]::Max($momentScale, [Math]::Abs($moment3[$index]))
}
$normalizedMoment = [Math]::Abs($sapInterfaceMoment)/$momentScale
if ($normalizedMoment -gt 1e-6) {
    throw ('SAP interface moment is not zero: {0:R} N*mm ' +
        '(normalized {1:E6}).' -f $sapInterfaceMoment, $normalizedMoment)
}

Write-Output ('Updated {0} base joints to R2 = {1:R} N*mm/rad.' -f `
    $baseJoints.Count, $baseRotationK)
Write-Output ('Set common story height to {0:R} mm.' -f $storyHeight)
Write-Output ('First-mode floor forces: {0:R}, {1:R}, {2:R} N.' -f `
    $floorForces[0], $floorForces[1], $floorForces[2])
Write-Output ('SAP interface moment: {0:R} N*mm (normalized {1:E6}).' -f `
    $sapInterfaceMoment, $normalizedMoment)
Write-Output ('Saved SAP model: {0}' -f $resolvedModelPath)
