using namespace System.Diagnostics
using namespace System.IO
using namespace System.Net
using namespace System.Text.RegularExpressions

# you can change these if you want/need to
$makeBackup = $true
$checkHash = $true
$useLog = $true
$deletePatchFile = $true
$deleteTempFiles = $true
$keepWindowOpen = $true

# you shouldn't need to change anything below this line
$patchUri = "http://www.sb-online.org/maluc/index.php?did=bh5fixes"

$ErrorActionPreference = 'Stop'

# starts logging
if ($useLog)
{
    $logFile = [Path]::ChangeExtension($PSCommandPath, ".log")
    Start-Transcript -Path $logFile -UseMinimalHeader
}

Function Initialize-Directory([string] $path) {
    if (!(Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

Function Get-FileName([string] $filePath) {
    return [Path]::GetFileName($filePath)
}

Function Get-FileNameNoExt([string] $filePath) {
    return [Path]::GetFileNameWithoutExtension($filePath)
}

Function Get-SteamPath() {
    $steamPath = Get-ItemProperty -Path HKCU:\Software\Valve\Steam | Select-Object -ExpandProperty "SteamPath"
    if ([string]::IsNullOrEmpty($steamPath)) {
        Throw "Unable to find the Steam install path."
    }
    return $steamPath
}

Function Test-IsRE5Running() {
    $procs = [Process]::GetProcessesByName("re5dx9")
    return $procs.Length -gt 0
}

Function Get-RE5InstallPath()
{
    # check the registry
    $regPath = "HKLM:\SOFTWARE\WOW6432Node\Capcom\RESIDENT EVIL 5"

    if (Test-Path $regPath) {
        $re5RegKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Capcom\RESIDENT EVIL 5"
        $re5InstallDir = $re5RegKey.installdir
        if (Test-Path $re5InstallDir) {
            return $re5InstallDir
        }
    }

    # check the default install path
    $steamPath = Get-SteamPath
    $defaultLibrary = Join-Path $steamPath "steamapps\common"
    $defaultInstallPath = Join-Path $defaultLibrary "Resident Evil 5"
    
    if (Test-Path $defaultInstallPath) {
        return $defaultInstallPath
    }

    # check each location in the libraryfolders.vdf config
    $libraryFoldersPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"

    if (Test-Path $libraryFoldersPath)
    {
        $libraryConfig = [File]::ReadAllText($libraryFoldersPath)

        $libraryRegex = New-Object Regex('^\t{1}"(?<id>[0-9]+)"\t{2}"(?<path>.+)"$')    
        [MatchCollection] $matches = $libraryRegex.Matches($libraryConfig)

        foreach ($match in $matches) {
            $libraryPath = $match.Groups["path"].Value
            $testRE5Path = Join-Path $libraryPath "steamapps\common\Resident Evil 5"
            if (Test-Path $testRE5Path) {
                return $testRE5Path
            }
        }
    }    

    Throw "Unable to determine the install location of Resident Evil 5."
}

Function Get-WinRarExe() {
    $winRarPath = Get-ItemProperty -Path HKLM:\SOFTWARE\WinRAR | Select-Object -ExpandProperty "exe64"
    $installPath = Split-Path $winRarPath
    $commandLinePath = Join-Path $installPath "rar.exe"
    if (Test-Path $commandLinePath)
    {
        return $commandLinePath
    }
    Throw "Unable to determine the location of 'rar.exe'. Please make sure WinRAR is installed and try again."
}

try {

    # first thing is to check and see if RE5 is currently running
    if (Test-IsRE5Running) {
        Throw "Unable to apply the patch because the Resident Evil 5 process (re5dx9.exe) is currently running."
    }

    # ----------------------------------------------------------------------------------------
    # create backup folder (if $makeBackup is $true)
    # ----------------------------------------------------------------------------------------
    if ($makeBackup)
    {
        $dateFormat = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $backupPath = Join-Path $PSScriptRoot "backup_$dateFormat"
    
        Initialize-Directory $backupPath
    }

    # ----------------------------------------------------------------------------------------
    # gets the patch page so we can use RegEx and get the link to download the file
    # and (optionally) get the expected MD5 hash of the patch file
    # ----------------------------------------------------------------------------------------
    $patchSiteContent = (Invoke-WebRequest -Uri $patchUri).Content

    # uses RegEx to determine the link to download the file
    $downloadLinkRegEx = New-Object Regex('href=\"(?<link>download\.php\?f\=(?<file>[a-zA-Z0-9\-]+))\".+\.rar')
    $linkMatch = $downloadLinkRegEx.Match($patchSiteContent)
    if (!($linkMatch.Success)) {
        Throw "Unable to determine the download link from '$patchUri'."
    }
    $relativeLink = $linkMatch.Groups["link"].Value
    $downloadUri = "http://www.sb-online.org/maluc/$relativeLink"

    # downloads the patch from the link we just parsed out
    $response = Invoke-WebRequest -Uri $downloadUri -Headers @{
        "Upgrade-Insecure-Requests" = "1"
        "User-Agent"                = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.150 Safari/537.36"
        "Accept"                    = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        "Referer"                   = "http://www.sb-online.org/maluc/index.php?did=bh5fixes"
        "Accept-Encoding"           = "gzip, deflate"
        "Accept-Language"           = "en-US,en;q=0.9"
    }

    $contentDispositionHeader = $response.Headers["Content-Disposition"]
    $fileNameRegEx = New-Object Regex("filename\=(?<filename>.+\.rar)$")
    $fileNameMatch = $fileNameRegEx.Match($contentDispositionHeader)

    # if we couldn't determine the file name to save the patch as from the
    # Content-Disposition header in the response then use the file name
    # from the download link (download.php?f=<file>)
    if ($fileNameMatch.Success) {
        $patchFileName = $fileNameMatch.Groups["filename"].Value
    }
    else {
        $linkFileName = $linkMatch.Groups["file"].Value
        $patchFileName = [Path]::ChangeExtension($linkFileName, ".rar")

        Write-Warning "Unable to determine the file name from the 'Content-Disposition' header. " +
        "Using the name from the download link ($patchFileName)."
    }

    $patchFilePath = Join-Path $PSScriptRoot $patchFileName
    $patchFileNameNoExt = [Path]::GetFileNameWithoutExtension($patchFileName)

    [System.IO.File]::WriteAllBytes($patchFilePath, $response.Content)

    # ----------------------------------------------------------------------------------------
    # if $checkHash is $true this will go to the official patch page and using RegEx parse
    # out the expected MD5 hash of the patch file and then compare it to the actual hash of
    # the patch file
    # ----------------------------------------------------------------------------------------
    if ($checkHash) {
        $hashRegEx = New-Object Regex("MD5:\s+(?<hash>[a-f0-9]{32})")
        $match = $hashRegEx.Match($patchSiteContent)

        if (!$match.Success) {
            Throw "Unable to determine the expected MD5 hash of the patch file."
        }

        $expectedHash = $match.Groups["hash"].Value.ToUpper()
        $hash = Get-FileHash $patchFilePath -Algorithm MD5
        $actualHash = $hash.Hash.ToUpper()
        $isHashMatch = $expectedHash -eq $actualHash
        $hashColor = switch ($isHashMatch) {
            $true { [ConsoleColor]::Green }
            $false { [ConsoleColor]::Red }
        }

        Write-Host "Expected Hash: " -NoNewline
        Write-Host $expectedHash -ForegroundColor $hashColor
        Write-Host "Actual Hash:   " -NoNewline
        Write-Host $actualHash -ForegroundColor $hashColor

        if (!$isHashMatch) {
            Throw "The actual MD5 hash of file '$patchFileName' does not match the expected hash."
        }
    }

    # ----------------------------------------------------------------------------------------
    # gets the current WinRAR install path and then extracts the patch archive
    # ----------------------------------------------------------------------------------------
    $winRarExe = Get-WinRarExe
    $extractPath = Join-Path $PSScriptRoot $patchFileNameNoExt

    Initialize-Directory $extractPath
    Set-Location $extractPath

    . "$winRarExe" x -y "$patchFilePath" *> $null
    
    Set-Location $PSScriptRoot

    # ----------------------------------------------------------------------------------------
    # gets the install location of RE5
    # ----------------------------------------------------------------------------------------
    $re5Path = Get-RE5InstallPath

    # ----------------------------------------------------------------------------------------
    # loops through each of the patch files and makes a backup of the original file (if 
    # $makeBackup is $true). then it will copy over the new patched file to the corresponding
    # path relative to $re5Path
    # ----------------------------------------------------------------------------------------
    $patchFiles = Get-ChildItem $extractPath -File -Recurse

    foreach ($patchedFile in $patchFiles) {
        $relativePath = $extractPath.Replace($extractPath, [string]::Empty)
        $originalFilePath = Join-Path $re5Path $relativePath
        $originalFileExists = Test-Path $originalFilePath

        # ----------------------------------------------------------------------------------------
        # creates a backup copy of the original files in the RE5 install directory just to be safe
        # ----------------------------------------------------------------------------------------
        if ($makeBackup) {
            $backupFilePath = Join-Path $backupPath $relativePath

            if ($originalFileExists) {
                Initialize-Directory (Split-Path $backupFilePath)

                Write-Host "Backing up file '$relativePath'... " -NoNewline
                try {
                    Copy-Item $originalFilePath -Destination $backupFilePath -Force | Out-Null
                    Write-Host "OK" -ForegroundColor Green
                }
                catch {
                    Write-Host "ERROR`r`n" -ForegroundColor Red
                    throw
                }
            }
        }

        Write-Host "Copying patch file '$relativePath'... " -NoNewline

        try {
            Copy-Item $patchedFile -Destination $originalFilePath -Force | Out-Null
            Write-Host "OK" -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR`r`n" -ForegroundColor Red
            throw
        }
    }

    Write-Host
    Write-Host "Patch '$patchFileNameNoExt' installed successfully.`r`n" -ForegroundColor Green
}
catch
{
    $ex = $_.Exception
    $exStackTrace = $_.ScriptStackTrace
    $errorType = $ex.GetType()

    $message = @"
    An unhandled $errorType occurred while attempting to install the RE5 community patch.

    Message:
    $($ex.Message)

    Source:
    $($ex.Source)

    StackTrace:
    $exStackTrace
"@

    Write-Host $message -ForegroundColor Red
}
finally
{
    # clean up the downloaded patch file
    if ($deletePatchFile -and (Test-Path $patchFilePath))
    {
        Remove-Item -Path $patchFilePath -Force | Out-Null
    }
    # clean up the extracted patch files
    if ($deleteTempFiles -and (Test-Path $extractPath))
    {
        Remove-Item -Path $extractPath -Recurse -Force | Out-Null
    }
}

Stop-Transcript

if ($keepWindowOpen)
{
    Write-Host "Press {ENTER} to exit..." -NoNewline
    Read-Host
}
