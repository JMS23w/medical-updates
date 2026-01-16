param(
  [string]$AppNameLike = "Medical",
  [string]$ExeName = "Medical.WPF.exe"
)

$ErrorActionPreference = "Stop"

# ===== URLs (RAW) en tu repo =====
$exeWebUrl = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/Medical.WPF.exe"

$dlls = @(
  @{ Name = "System.text.Formatting.dll"; Url = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/System.text.Formatting.dll" },
  @{ Name = "System.text.Identity.dll";   Url = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/System.text.Identity.dll" }
)

function Get-InstallDirByDisplayName($NameLike){
  $keys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )

  $apps = foreach($k in $keys){
    Get-ItemProperty $k -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and $_.DisplayName -like "*$NameLike*" }
  }
  if(-not $apps){ return $null }

  $app = $apps | Sort-Object @{Expression={ if($_.DisplayName -eq $NameLike){0}else{1} }}, DisplayName | Select-Object -First 1

  if($app.InstallLocation -and (Test-Path $app.InstallLocation)){ return $app.InstallLocation }

  if($app.DisplayIcon){
    $p = $app.DisplayIcon.Split(",")[0].Trim('"')
    if(Test-Path $p){ return (Split-Path $p -Parent) }
  }

  if($app.UninstallString){
    $u = $app.UninstallString.Trim()
    if($u -match '("([^"]+\.exe)"|([^\s"]+\.exe))'){
      $exe = ($Matches[2] ? $Matches[2] : $Matches[3]).Trim('"')
      if(Test-Path $exe){ return (Split-Path $exe -Parent) }
    }
  }
  return $null
}

$installDir = Get-InstallDirByDisplayName $AppNameLike
if(-not $installDir){ throw "No pude detectar la ruta instalada de '$AppNameLike'." }

$exePath = Join-Path $installDir $ExeName
if(-not (Test-Path $exePath)){ throw "Encontré InstallDir ($installDir) pero no existe $ExeName ahí." }

Write-Host "InstallDir:" $installDir
Write-Host "Actualizando..." 

# Cerrar app
$procName = [IO.Path]::GetFileNameWithoutExtension($ExeName)
Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2

# Backup
$backup = Join-Path $installDir ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $exePath -Destination $backup -Force
Get-ChildItem $installDir -Filter *.dll -ErrorAction SilentlyContinue | ForEach-Object {
  Copy-Item $_.FullName -Destination $backup -Force
}

# Temp
$tmp = Join-Path $env:TEMP ("medical_upd_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

# Descargar EXE
$newExe = Join-Path $tmp $ExeName
Invoke-WebRequest $exeWebUrl -OutFile $newExe -UseBasicParsing

# Reemplazar EXE
Copy-Item $newExe -Destination $exePath -Force
Unblock-File $exePath -ErrorAction SilentlyContinue

# Descargar y copiar DLLs (nuevas o existentes)
foreach($d in $dlls){
  $name = $d.Name
  $url  = $d.Url
  $dest = Join-Path $installDir $name
  $src  = Join-Path $tmp $name

  Write-Host "DLL:" $name
  Invoke-WebRequest $url -OutFile $src -UseBasicParsing

  Copy-Item $src -Destination $dest -Force
  Unblock-File $dest -ErrorAction SilentlyContinue
}

# Abrir app
Start-Process -FilePath $exePath -WorkingDirectory $installDir

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK: Medical actualizado."
