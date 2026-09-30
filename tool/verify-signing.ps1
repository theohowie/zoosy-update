# ============================================================================
#  签名自检：确认 release APK 的签名满足两条升级路径
#
#  A) API 24-27（Android 7.0-8.1）走 v2 签名：
#     必须由旧 debug 密钥签名，否则 <= v1.15.0 的老用户无法覆盖安装。
#  B) API 28+（Android 9+）走 v3 签名：
#     必须由 upload 密钥签名，并能识别 debug 密钥的轮换来源，
#     这样 <= v1.15.0（debug 签名）的用户也能直接升级。
#
#  用法:
#     powershell -ExecutionPolicy Bypass -File tool\verify-signing.ps1 -ApkDir build\app\outputs\flutter-apk
#     powershell -ExecutionPolicy Bypass -File tool\verify-signing.ps1 -Apk release\zoosy-v1.18.1.apk
# ============================================================================

param(
    [string]$Apk,
    [string]$ApkDir,
    [string]$LegacySha256 = 'b86ca741935a0e9452ec3df855939d00c9ebc258300ba37ae852ead636ccb53b',
    [string]$UploadSha256 = 'dd5e9d9db844554359eef32177ba5b14424e606a393778e3ca80c3848643d852'
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Host "[verify-signing] 出错: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent $scriptDir
$androidDir = Join-Path $repoRoot 'android'

# ---------------------------------------------------------------- 收集 APK
$targets = @()
if ($Apk) {
    if (-not (Test-Path -LiteralPath $Apk)) { Write-Host "找不到 APK: $Apk" -ForegroundColor Red; exit 1 }
    $targets = @(Get-Item -LiteralPath $Apk)
}
if ($ApkDir) {
    if (-not (Test-Path -LiteralPath $ApkDir)) { Write-Host "找不到目录: $ApkDir" -ForegroundColor Red; exit 1 }
    $found = @(Get-ChildItem -LiteralPath $ApkDir -Filter '*.apk' -File | Where-Object { $_.Name -notlike '*debug*' })
    $targets = @($targets) + @($found)
}
if ($targets.Count -eq 0) { Write-Host '没有找到需要检查的 APK' -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- apksigner
$sdkRoots = @()
if ($env:ANDROID_SDK_ROOT) { $sdkRoots += $env:ANDROID_SDK_ROOT }
if ($env:ANDROID_HOME)     { $sdkRoots += $env:ANDROID_HOME }
$localProps = Join-Path $androidDir 'local.properties'
if (Test-Path $localProps) {
    $m = Select-String -Path $localProps -Pattern '^sdk\.dir\s*=\s*(.+)$'
    if ($m) { $sdkRoots += ($m.Matches[0].Groups[1].Value.Trim() -replace '\\\\', '\') }
}
$sdkRoots += (Join-Path $env:LOCALAPPDATA 'Android\Sdk')

$apksigner = $null
foreach ($root in $sdkRoots) {
    $bt = Join-Path $root 'build-tools'
    if (Test-Path $bt) {
        $cand = @(Get-ChildItem $bt -Directory | Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } |
            Where-Object { Test-Path $_ })
        if ($cand.Count -gt 0) { $apksigner = $cand[0]; break }
    }
}
if (-not $apksigner) { Write-Host '找不到 apksigner（Android SDK build-tools）' -ForegroundColor Red; exit 1 }

$failed = $false
for ($i = 0; $i -lt $targets.Count; $i++) {
    $apkFile = $targets[$i]
    $apkPath = $apkFile.FullName
    $apkName = $apkFile.Name
    $sizeMb  = [math]::Round(([double]$apkFile.Length) / 1MB, 2)

    Write-Host ""
    Write-Host ("=== {0}  ({1} MB) ===" -f $apkName, $sizeMb) -ForegroundColor Cyan

    # --- A) API 24-27（v2 路径）---
    $v2Args = @('verify', '--print-certs', '-v', '--min-sdk-version', '24', '--max-sdk-version', '27', $apkPath)
    $v2Out  = (& $apksigner $v2Args 2>&1 | Out-String)
    $v2Ok   = $v2Out -match 'Verifies'
    $v2Dig  = if ($v2Out -match 'Signer #1 certificate SHA-256 digest:\s*([0-9a-f]+)') { $Matches[1] } else { '' }

    if (-not $v2Ok) {
        Write-Host "  [X] API 24-27 验签失败" -ForegroundColor Red; $failed = $true
    } elseif ($v2Dig -eq $LegacySha256) {
        Write-Host "  [OK] API 24-27 (v2) = 旧 debug 密钥 -> <=v1.15.0 老用户可覆盖安装" -ForegroundColor Green
    } else {
        Write-Host "  [X] API 24-27 (v2) 不是旧 debug 密钥 ($v2Dig)" -ForegroundColor Red
        Write-Host "      老用户（<=v1.15.0）覆盖安装会报签名冲突" -ForegroundColor Red
        $failed = $true
    }

    # --- B) API 28+（v3 路径）---
    $v3Args = @('verify', '--print-certs', '-v', '--min-sdk-version', '28', $apkPath)
    $v3Out  = (& $apksigner $v3Args 2>&1 | Out-String)
    $v3Ok   = $v3Out -match 'Verifies'
    $v3Dig  = if ($v3Out -match 'Signer #1 certificate SHA-256 digest:\s*([0-9a-f]+)') { $Matches[1] } else { '' }
    $hasV3  = $v3Out -match 'Verified using v3 scheme \(APK Signature Scheme v3\):\s*true'

    if (-not $v3Ok) {
        Write-Host "  [X] API 28+ 验签失败" -ForegroundColor Red; $failed = $true
    } elseif (-not $hasV3) {
        Write-Host "  [X] 缺少 v3 签名块 -> Android 9+ 无法识别密钥轮换" -ForegroundColor Red
        $failed = $true
    } elseif ($v3Dig -eq $UploadSha256) {
        Write-Host "  [OK] API 28+ (v3) = upload 密钥，且带轮换来源信息" -ForegroundColor Green
    } else {
        Write-Host "  [X] API 28+ (v3) 不是 upload 密钥 ($v3Dig)" -ForegroundColor Red
        Write-Host "      已装 v1.16.0+ 的用户将无法覆盖安装" -ForegroundColor Red
        $failed = $true
    }
}

Write-Host ""
if ($failed) {
    Write-Host "签名自检未通过" -ForegroundColor Red
    exit 1
}
Write-Host "签名自检通过" -ForegroundColor Green
exit 0
