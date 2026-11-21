# Gera a chave de release do Lydo e o android\key.properties.
# A senha é digitada só aqui, no seu terminal.
$ErrorActionPreference = 'Stop'
$jks = Join-Path $env:USERPROFILE '.lydo\lydo-release.jks'
$props = Join-Path $PSScriptRoot '..\android\key.properties'
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
if (-not (Test-Path $keytool)) { $keytool = 'keytool' }

if (Test-Path $jks) { Write-Host "Ja existe uma chave em $jks. Nada foi feito."; return }
New-Item -ItemType Directory -Force (Split-Path $jks) | Out-Null

do {
  $s1 = Read-Host 'Escolha a senha da chave (minimo 6 caracteres)' -AsSecureString
  $s2 = Read-Host 'Repita a senha' -AsSecureString
  $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s1))
  $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s2))
  $ok = ($p1 -eq $p2) -and ($p1.Length -ge 6)
  if (-not $ok) { Write-Host 'As senhas nao batem ou sao curtas. Tente de novo.' }
} until ($ok)

& $keytool -genkeypair -keystore $jks -alias lydo -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $p1 -keypass $p1 -dname 'CN=Lydo, O=Lydo, C=BR'
if ($LASTEXITCODE -ne 0) { Write-Host 'O keytool falhou.'; return }

$text = "storeFile=$($jks -replace '\\','/')`nstorePassword=$p1`nkeyAlias=lydo`nkeyPassword=$p1`n"
[IO.File]::WriteAllText($props, $text, (New-Object Text.UTF8Encoding($false)))
$p1 = $null; $p2 = $null
Write-Host ''
Write-Host "Pronto! Chave: $jks"
Write-Host 'Faca backup do .jks e da senha (Google Drive ou gerenciador de senhas).'
