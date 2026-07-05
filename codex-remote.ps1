$ErrorActionPreference = 'Stop'

# Local Codex CLI, remote repository mounted as a Windows SMB drive.
# This intentionally does not start MATLAB or any MCP server.

$remoteHost = if ($env:CODEX_REMOTE_HOST) { $env:CODEX_REMOTE_HOST } else { '100.122.58.104' }
$remoteUser = if ($env:CODEX_REMOTE_USER) { $env:CODEX_REMOTE_USER } else { 'BOWN1111PC1' }
$defaultRemoteAccount = if ($env:CODEX_REMOTE_ACCOUNT) { $env:CODEX_REMOTE_ACCOUNT } else { "DESKTOP-F1KL53J\$remoteUser" }
$remoteShareName = if ($env:CODEX_REMOTE_SHARE) { $env:CODEX_REMOTE_SHARE } else { 'ColumnSetup_gaurav' }
$remoteDrive = if ($env:CODEX_REMOTE_DRIVE) { $env:CODEX_REMOTE_DRIVE } else { 'R:' }
$expectedRemotePath = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav'

$remoteRepoShare = "\\$remoteHost\$remoteShareName"
$remoteAdminShare = "\\$remoteHost\C$"
$remoteRepoMain = "$remoteDrive\main"
$remoteAdminRepoMain = "$remoteDrive\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\main"

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)] [string] $HostName,
        [Parameter(Mandatory = $true)] [int] $Port,
        [int] $TimeoutMs = 4000
    )

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

Write-Host "Remote-mounted Codex launcher"
Write-Host "  Share: $remoteRepoShare"
Write-Host "  Drive: $remoteDrive"
Write-Host "  Default user: $defaultRemoteAccount"
Write-Host "  Remote path expected behind share: $expectedRemotePath"
Write-Host ""

Write-Host "Checking SMB/file-sharing port 445 on $remoteHost..."
if (-not (Test-TcpPort -HostName $remoteHost -Port 445)) {
    throw "Cannot reach $remoteHost on port 445. The remote folder cannot be mounted from this device until SMB is reachable through the same LAN, VPN, Tailscale, or another private network."
}
Write-Host "Port 445 is reachable."
Write-Host ""

$enteredRemoteAccount = Read-Host "Remote Windows account [$defaultRemoteAccount]"
if ([string]::IsNullOrWhiteSpace($enteredRemoteAccount)) {
    $remoteAccount = $defaultRemoteAccount
} else {
    $remoteAccount = $enteredRemoteAccount
}

$securePassword = Read-Host "Password for $remoteAccount@$remoteHost" -AsSecureString
$credential = [Management.Automation.PSCredential]::new($remoteAccount, $securePassword)
$plainPassword = $credential.GetNetworkCredential().Password

Write-Host ""
Write-Host "Removing any previous $remoteDrive mapping..."
cmd.exe /c "net use $remoteDrive /delete /y >nul 2>nul"
cmd.exe /c "net use \\$remoteHost\IPC$ /delete /y >nul 2>nul"
cmdkey.exe /delete:$remoteHost >$null 2>$null

Write-Host "Saving credentials for $remoteHost..."
& cmdkey.exe "/add:$remoteHost" "/user:$remoteAccount" "/pass:$plainPassword" | Out-Host
if ($LASTEXITCODE -ne 0) {
    $plainPassword = $null
    throw "Failed to save SMB credentials with cmdkey."
}

$plainPassword = $null

Write-Host "Mapping $remoteDrive to $remoteRepoShare..."
cmd.exe /c "net use $remoteDrive `"$remoteRepoShare`" /persistent:no"
$netUseExitCode = $LASTEXITCODE

if ($netUseExitCode -ne 0) {
    Write-Host ""
    Write-Host "The named share did not map. Available remote shares, if listing is allowed:"
    cmd.exe /c "net view \\$remoteHost"
    Write-Host ""
    Write-Host "Trying fallback admin share $remoteAdminShare..."
    cmd.exe /c "net use $remoteDrive `"$remoteAdminShare`" /persistent:no"
    $netUseExitCode = $LASTEXITCODE
    if ($netUseExitCode -ne 0) {
        throw "Failed to map $remoteDrive. Create the SMB share named '$remoteShareName' on the remote device pointing to '$expectedRemotePath', or use an administrator account that can access $remoteAdminShare."
    }

    $remoteRepoMain = $remoteAdminRepoMain
}

if (-not (Test-Path -LiteralPath $remoteRepoMain)) {
    throw "Mapped $remoteDrive, but $remoteRepoMain was not found. The shared folder should be ColumnSetup_gaurav and must contain a main folder."
}

Set-Location -LiteralPath $remoteRepoMain
Write-Host ""
Write-Host "Starting local Codex CLI in mounted remote folder:"
Write-Host "  $remoteRepoMain"
Write-Host ""

codex -c "mcp_servers={}"
