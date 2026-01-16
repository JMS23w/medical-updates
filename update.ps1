$ErrorActionPreference = "Stop"

# ====== URLs (RAW) de tu repo ======
$exeUrl  = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/Medical.WPF.exe"
$dll1Url = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/System.text.Formatting.dll"
$dll2Url = "https://raw.githubusercontent.com/JMS23w/medical-updates/main/System.text.Identity.dll"

# ====== Nombres ======
$exeName  = "Medical.WPF.exe"
$procName = "Medical.WPF"   # proceso sin .exe

$dll1Name = "System.text.Formatting.dll"
$dll2Name = "System.text.Identity.dll"

# ====== 1) Cerrar app si está abierta ======
Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2

# ====== 2) Encontrar la ruta real del EXE en ClickOnce cache ======
$root = Join-Path $env:LOCALAPPDATA "Apps\2.0"

$cands = Get-ChildItem $root -Recurse -Filter $exeName -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending

if(-not $cands -or $cands.Count -eq 0){
  throw "No encontré $exeName en $root. Ejecuta la app una vez y vuelve a intentar."
}

$targetExe = $cands[0].FullName
$targetDir = Split-Path $targetExe -Parent

Write-Host "Direccion detectada:"


# ====== 3) Backup ======
$backup = Join-Path $targetDir ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $backup | Out-Null

Copy-Item $targetExe -Destination $backup -Force

$dll1Dest = Join-Path $targetDir $dll1Name
$dll2Dest = Join-Path $targetDir $dll2Name

if(Test-Path $dll1Dest){ Copy-Item $dll1Dest -Destination $backup -Force }
if(Test-Path $dll2Dest){ Copy-Item $dll2Dest -Destination $backup -Force }

# ====== 4) Descargar a TEMP ======
$tmp = Join-Path $env:TEMP ("medical_clickonce_upd_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

$newExe  = Join-Path $tmp $exeName
$newDll1 = Join-Path $tmp $dll1Name
$newDll2 = Join-Path $tmp $dll2Name

Invoke-WebRequest $exeUrl  -OutFile $newExe  -UseBasicParsing
Invoke-WebRequest $dll1Url -OutFile $newDll1 -UseBasicParsing
Invoke-WebRequest $dll2Url -OutFile $newDll2 -UseBasicParsing

# (Opcional) Desbloquear archivos descargados
Unblock-File $newExe  -ErrorAction SilentlyContinue
Unblock-File $newDll1 -ErrorAction SilentlyContinue
Unblock-File $newDll2 -ErrorAction SilentlyContinue

# ====== 5) Copiar/reemplazar en Apps\2.0 ======
Copy-Item $newExe  -Destination $targetExe -Force
Copy-Item $newDll1 -Destination $dll1Dest -Force  # si no existe, lo crea
Copy-Item $newDll2 -Destination $dll2Dest -Force

# ====== 6) Abrir la app ======
Start-Process -FilePath $targetExe -WorkingDirectory $targetDir

# Limpieza
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "OK: Actualización aplicada en ClickOnce cache."

