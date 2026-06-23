# Units:
# Inputs/outputs use force [N], length [m], rotational stiffness [N*m/rad],
# moment [N*m], and dimensionless normalized checks.
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
$allFloorForces = @()
foreach ($forceRow in $FloorForcesText.Split(';')) {
    [double[]]$values = @(
        $forceRow.Split(',') | ForEach-Object {
            [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture)
        }
    )
    if ($values.Count -ne 3) {
        throw 'Each FloorForcesText row must contain three comma-separated values.'
    }
    $allFloorForces += ,$values
}
[double[]]$floorForces = $allFloorForces[0]

Add-Type -Path $apiPath
[CSiAPIv1.cHelper]$helper = [CSiAPIv1.Helper]::new()
[CSiAPIv1.cOAPI]$application = $null
$startedApplication = $false
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
        [CSiAPIv1.eUnits]::N_m_C,
        [bool]$true,
        [string]''
    )
    $startResult = $startMethod.Invoke($application, $startArguments)
    if ($startResult -ne 0) {
        throw "SAP2000 failed to start (return code $startResult)."
    }
    $startedApplication = $true
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
$initializeResult = $model.InitializeNewModel([CSiAPIv1.eUnits]::N_m_C)
$blankResult = $model.File.NewBlank()
if ($initializeResult -ne 0 -or $blankResult -ne 0) {
    throw 'SAP2000 failed to initialize the N-m-C template.'
}
[bool[]]$activeDofs = @($true, $false, $true, $false, $true, $false)
if ($model.Analyze.SetActiveDOF([ref]$activeDofs) -ne 0) {
    throw 'SAP2000 failed to set the planar active degrees of freedom.'
}

$material = 'STEEL_E200'
if ($model.PropMaterial.SetMaterial(
        $material, [CSiAPIv1.eMatType]::Steel, -1, '', '') -ne 0 -or `
    $model.PropMaterial.SetMPIsotropic(
        $material, 200e9, 0.3, 1.17e-5, 0) -ne 0) {
    throw 'SAP2000 failed to define the SI steel material.'
}
$sections = @(
    @{Name='W8X24'; Values=[double[]]@(
        0.20142199563980103, 0.1651, 0.004567732750778198,
        0.0012534491019392012, 0.0027956934358787535,
        1.44016067402599e-7, 7.617034770920623e-6,
        3.442233762688249e-5, 9.227177190697302e-5,
        3.417932338277422e-4, 1.4043713347906495e-4,
        3.7854118465116875e-4, 0.0408359464775658,
        0.08681001612235472)},
    @{Name='W8X28'; Values=[double[]]@(
        0.20472401065826416, 0.1661159990310669, 0.00532257,
        0.0014819970793151854, 0.003269993487071991,
        2.235162757456746e-7, 9.032222253079375e-6,
        4.0790679708799995e-5, 1.0874596433532181e-4,
        3.9849433955150376e-4, 1.655093526511688e-4,
        4.457281533023376e-4, 0.04119425157340637,
        0.08754266838450144)},
    @{Name='W8X35'; Values=[double[]]@(
        0.20624799709320068, 0.20370801162719727,
        0.006645148123054504, 0.0016239967475700378,
        0.004268701076011657, 3.2008196370623005e-7,
        1.7731458095441245e-5, 5.2861391051199995e-5,
        1.740869978927613e-4, 5.126002850569516e-4,
        2.638317366511688e-4, 5.686311333023376e-4,
        0.05165589516693229, 0.08919016363694514)}
)
foreach ($section in $sections) {
    [double[]]$v = $section.Values
    if ($model.PropFrame.SetGeneral(
            [string]$section.Name, $material, $v[0], $v[1], $v[2],
            $v[3], $v[4], $v[5], $v[6], $v[7], $v[8], $v[9],
            $v[10], $v[11], $v[12], $v[13], -1, '', '') -ne 0) {
        throw "SAP2000 failed to define section $($section.Name) in SI."
    }
    [double[]]$sectionModifiers = @(1, 1e10, 1e10, 1, 1, 1, 1, 1)
    if ($model.PropFrame.SetModifiers(
            [string]$section.Name, [ref]$sectionModifiers) -ne 0) {
        throw "SAP2000 failed to set section modifiers for $($section.Name)."
    }
}

$bayWidth = 3.048
$templateStoryHeight = 2.033016
for ($level = 0; $level -le 3; $level++) {
    for ($grid = 0; $grid -le 3; $grid++) {
        $joint = 'J_L{0}_G{1}' -f $level, $grid
        [string]$assignedJoint = ''
        if ($model.PointObj.AddCartesian(
                $grid*$bayWidth, 0, $level*$templateStoryHeight, `
                [ref]$assignedJoint, $joint, 'GLOBAL', $false, 0) -ne 0) {
            throw "SAP2000 failed to create joint $joint."
        }
    }
}
[string]$assignedInterface = ''
if ($model.PointObj.AddCartesian(
        0, 0, 1.016, [ref]$assignedInterface, 'J_INTERFACE', `
        'GLOBAL', $false, 0) -ne 0) {
    throw 'SAP2000 failed to create J_INTERFACE.'
}

for ($level = 1; $level -le 3; $level++) {
    for ($bay = 1; $bay -le 3; $bay++) {
        $frameName = 'B_L{0}_B{1}' -f $level, $bay
        [string]$assignedFrame = ''
        if ($model.FrameObj.AddByPoint(
                ('J_L{0}_G{1}' -f $level, ($bay-1)), `
                ('J_L{0}_G{1}' -f $level, $bay), `
                [ref]$assignedFrame, 'W8X24', $frameName) -ne 0) {
            throw "SAP2000 failed to create frame $frameName."
        }
    }
}
for ($grid = 1; $grid -le 3; $grid++) {
    $columnSection = 'W8X35'
    if ($grid -eq 3) { $columnSection = 'W8X28' }
    for ($story = 1; $story -le 3; $story++) {
        $frameName = 'C_G{0}_S{1}' -f $grid, $story
        [string]$assignedFrame = ''
        if ($model.FrameObj.AddByPoint(
                ('J_L{0}_G{1}' -f ($story-1), $grid), `
                ('J_L{0}_G{1}' -f $story, $grid), `
                [ref]$assignedFrame, $columnSection, $frameName) -ne 0) {
            throw "SAP2000 failed to create frame $frameName."
        }
    }
}
$leftFrames = @(
    @('J_L0_G0', 'J_INTERFACE', 'C_G0_S1_LOWER_EXP'),
    @('J_INTERFACE', 'J_L1_G0', 'C_G0_S1_UPPER'),
    @('J_L1_G0', 'J_L2_G0', 'C_G0_S2'),
    @('J_L2_G0', 'J_L3_G0', 'C_G0_S3')
)
foreach ($frame in $leftFrames) {
    [string]$assignedFrame = ''
    if ($model.FrameObj.AddByPoint(
            [string]$frame[0], [string]$frame[1], [ref]$assignedFrame, `
            'W8X28', [string]$frame[2]) -ne 0) {
        throw "SAP2000 failed to create frame $($frame[2])."
    }
}

[bool[]]$floorDofs = @($true, $true, $true, $false, $false, $false)
for ($level = 1; $level -le 3; $level++) {
    $constraintName = 'floor{0}' -f $level
    if ($model.ConstraintDef.SetBody(
            $constraintName, [ref]$floorDofs, 'GLOBAL') -ne 0) {
        throw "SAP2000 failed to define $constraintName."
    }
    for ($grid = 0; $grid -le 3; $grid++) {
        [string]$assignedConstraint = $constraintName
        if ($model.PointObj.SetConstraint(
                ('J_L{0}_G{1}' -f $level, $grid), `
                [ref]$assignedConstraint, `
                [CSiAPIv1.eItemType]::Objects, $true) -ne 0) {
            throw "SAP2000 failed to assign $constraintName."
        }
    }
}
[bool[]]$baseRestraint = @($true, $true, $true, $false, $false, $false)
[double[]]$templateSpring = @(0, 0, 0, 0, 1.04e7, 0)
foreach ($joint in @('J_L0_G0', 'J_L0_G1', 'J_L0_G2', 'J_L0_G3')) {
    [bool[]]$restraint = $baseRestraint.Clone()
    if ($model.PointObj.SetRestraint(
            $joint, [ref]$restraint, [CSiAPIv1.eItemType]::Objects) -ne 0) {
        throw "SAP2000 failed to restrain $joint."
    }
    [double[]]$spring = $templateSpring.Clone()
    if ($model.PointObj.SetSpring(
            $joint, [ref]$spring, [CSiAPIv1.eItemType]::Objects, `
            $false, $true) -ne 0) {
        throw "SAP2000 failed to assign the template spring at $joint."
    }
}
if ($model.File.Save($resolvedTemplatePath) -ne 0) {
    throw 'SAP2000 failed to save the rebuilt N-m-C template.'
}
Write-Output 'SAP stage: rebuilt and saved the template in N-m-C database units.'

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

$unitsResult = $model.SetPresentUnits([CSiAPIv1.eUnits]::N_m_C)
if ($unitsResult -ne 0) {
    throw "SAP2000 failed to set N-m-C units (return code $unitsResult)."
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
# Verify the floor and interface elevations before changing any loads.
foreach ($entry in $targetCoordinates.GetEnumerator()) {
    [double]$x = 0
    [double]$y = 0
    [double]$z = 0
    $coordinateResult = $model.PointObj.GetCoordCartesian(
        $entry.Key, [ref]$x, [ref]$y, [ref]$z, 'GLOBAL')
    if ($coordinateResult -ne 0 -or `
        [Math]::Abs($z - [double]$entry.Value) -gt 1e-6) {
        $coordinateMessage = (('Coordinate verification failed for {0}: ' +
            'expected Z={1:R} m, actual Z={2:R} m, difference={3:E6} m, ' +
            'present units={4}.') -f $entry.Key, [double]$entry.Value, $z, `
            [Math]::Abs($z - [double]$entry.Value), $model.GetPresentUnits())
        throw $coordinateMessage
    }
}
Write-Output 'SAP stage: updated and verified floor coordinates.'

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

# Optional semicolon-separated rows add higher-mode equivalent-force cases.
for ($modeIndex = 1; $modeIndex -lt $allFloorForces.Count; $modeIndex++) {
    $pattern = 'MODE{0}_EQ' -f ($modeIndex + 1)
    [void]$model.LoadPatterns.Delete($pattern)
    if ($model.LoadPatterns.Add(
            $pattern,
            [CSiAPIv1.eLoadPatternType]::Other,
            0.0,
            $true) -ne 0) {
        throw "Failed to create load pattern $pattern."
    }
    [double[]]$modeForces = $allFloorForces[$modeIndex]
    for ($level = 1; $level -le 3; $level++) {
        [double[]]$jointLoad = @($modeForces[$level - 1], 0, 0, 0, 0, 0)
        $jointName = 'J_L{0}_G0' -f $level
        if ($model.PointObj.SetLoadForce(
                $jointName,
                $pattern,
                [ref]$jointLoad,
                $true,
                'GLOBAL',
                [CSiAPIv1.eItemType]::Objects) -ne 0) {
            throw "Failed to assign $pattern at $jointName."
        }
    }
    Write-Output ('SAP stage: assigned {0} floor forces: {1:R}, {2:R}, {3:R} N.' -f `
        $pattern, $modeForces[0], $modeForces[1], $modeForces[2])
}

$saveResult = $model.File.Save($resolvedModelPath)
if ($saveResult -ne 0) {
    throw "SAP2000 failed to save the specimen model (return code $saveResult)."
}
Write-Output 'SAP stage: saved the edited specimen model.'

# Solve the first-mode equivalent static case and verify the moment at the
# top of the lower experimental-column segment.
[void]$model.Analyze.SetRunCaseFlag('', $false, $true)
for ($modeIndex = 0; $modeIndex -lt $allFloorForces.Count; $modeIndex++) {
    $pattern = 'MODE{0}_EQ' -f ($modeIndex + 1)
    if ($model.Analyze.SetRunCaseFlag($pattern, $true, $false) -ne 0) {
        throw "Failed to select $pattern for analysis."
    }
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
    throw ((('SAP interface moment is not zero: {0:R} N*m ' +
        '(normalized {1:E6}).') -f $sapInterfaceMoment, $normalizedMoment))
}

Write-Output ('Updated {0} base joints to R2 = {1:R} N*m/rad.' -f `
    $baseJoints.Count, $baseRotationK)
Write-Output ('Set common story height to {0:R} m.' -f $storyHeight)
Write-Output ('First-mode floor forces: {0:R}, {1:R}, {2:R} N.' -f `
    $floorForces[0], $floorForces[1], $floorForces[2])
Write-Output ('SAP interface moment: {0:R} N*m (normalized {1:E6}).' -f `
    $sapInterfaceMoment, $normalizedMoment)
Write-Output ('Saved SAP model: {0}' -f $resolvedModelPath)
if ($startedApplication) {
    [void]$application.ApplicationExit($false)
    Write-Output 'SAP stage: closed the API instance started by this helper.'
}
