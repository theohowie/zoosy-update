# ============================================================================
#  Zoosy 正式版 APK 构建脚本
#
#  为什么需要这个脚本（而不是直接 flutter build apk）？
#  ---------------------------------------------------------------------------
#  历史原因：<= v1.15.0 的正式包使用 Android 默认 debug 密钥签名，
#  v1.16.0 起改用 upload 密钥签名。Android 只允许签名一致的包覆盖安装，
#  因此老用户升级时会报「签名冲突 / 应用未安装」。
#
#  解决办法是 APK Signature Scheme v3 的签名密钥轮换（key rotation）：
#  新包在 v3 签名块里带上 debug -> upload 的轮换证明（lineage），
#  Android 9（API 28）及以上即可校验通过并直接覆盖安装。
#
#  这个脚本在 flutter build 之后对 APK 追加轮换签名，并做自检。
#  普通 flutter build apk 只会产出 upload 单签名的包（已装 v1.16.0+ 的用户正常，
#  但 <= v1.15.0 的老用户无法覆盖安装）。
#
#  用法:
#     powershell -ExecutionPolicy Bypass -File tool\build-release.ps1
#     powershell -ExecutionPolicy Bypass -File tool\build-release.ps1 -Version 1.18.1
#     powershell -ExecutionPolicy Bypass -File tool\build-release.ps1 -SkipBuild
# ============================================================================

[CmdletBinding()]
param(
    [string]$Version,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $RepoRoot 'android'
$KeyProps   = Join-Path $AndroidDir 'key.properties'
$OutputDir  = Join-Path $RepoRoot 'build\app\outputs\flutter-apk'
$ReleaseDir = Join-Path $RepoRoot 'release'

function Write-Step([string]$msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)    { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2([string]$msg) { Write-Host "    [!]  $msg" -ForegroundColor Yellow }
function Fail([string]$msg)        { Write-Host "    [X]  $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 读取配置
if (-not (Test-Path $KeyProps)) { Fail "缺少 $KeyProps（签名配置，不入库）" }

$props = @{}
Get-Content $KeyProps -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $i = $line.IndexOf('=')
        $props[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
    }
}

# 相对路径按 AGP 习惯解析为 android/app/<p>，否则按 android/<p>
function Resolve-FromAndroid([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ([System.IO.Path]::IsPathRooted($p)) { return (Resolve-Path $p).Path }
    foreach ($base in @((Join-Path $AndroidDir 'app'), $AndroidDir)) {
        $candidate = Join-Path $base $p
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }
    throw "找不到文件: $p"
}

$uploadKs    = Resolve-FromAndroid $props['storeFile']
$uploadAlias = $props['keyAlias']
$uploadStore = $props['storePassword']
$uploadKey   = $props['keyPassword']

if (-not $uploadKs) { Fail 'key.properties 中缺少 storeFile' }

$legacyKs      = if ($props['legacyStoreFile']) { Resolve-FromAndroid $props['legacyStoreFile'] } else { $null }
$legacyAlias   = $props['legacyKeyAlias']
$legacyStore   = $props['legacyStorePassword']
$legacyKeyPass = $props['legacyKeyPassword']
$lineageFile   = if ($props['lineageFile'])     { Resolve-FromAndroid $props['lineageFile'] }     else { $null }

$rotationEnabled = $legacyKs -and $lineageFile -and (Test-Path $legacyKs) -and (Test-Path $lineageFile)

# ------------------------------------------------------- 构建
if (-not $SkipBuild) {
    Write-Step '构建 release APK'
    Push-Location $RepoRoot
    try {
        # flutter/gradle 会往 stderr 写进度信息，这里用 cmd 调用并把 stderr 合并，
        # 避免 PowerShell 把正常输出当成错误（$ErrorActionPreference = 'Stop'）
        $buildCmd = 'flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols 2>&1'
        $buildOut = & cmd /c $buildCmd
        $buildCode = $LASTEXITCODE
        $buildOut | ForEach-Object { Write-Host "    $_" }
        if ($buildCode -ne 0) { Fail "flutter build apk 失败（exit $buildCode）" }
    } finally { Pop-Location }
}

if (-not (Test-Path $OutputDir)) { Fail "找不到 APK 输出目录: $OutputDir" }

$apks = @(Get-ChildItem $OutputDir -Filter '*.apk' -File | Where-Object { $_.Name -notlike '*debug*' })
if ($apks.Count -eq 0) { Fail "找不到 APK 产物: $OutputDir" }

# 版本号（用于归档命名）
if (-not $Version) {
    $pubspec = Get-Content (Join-Path $RepoRoot 'pubspec.yaml') -Raw
    if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { $Version = $Matches[1] }
}
if (-not $Version) { Fail '无法确定版本号，请用 -Version 指定' }

# ------------------------------------------------------- 定位 apksigner
function Find-ApkSigner {
    $candidates = @()
    if ($env:ANDROID_SDK_ROOT) { $candidates += $env:ANDROID_SDK_ROOT }
    if ($env:ANDROID_HOME)     { $candidates += $env:ANDROID_HOME }
    $localProps = Join-Path $AndroidDir 'local.properties'
    if (Test-Path $localProps) {
        $m = Select-String -Path $localProps -Pattern '^sdk\.dir\s*=\s*(.+)$'
        if ($m) { $candidates += ($m.Matches[0].Groups[1].Value -replace '\\\\', '\') }
    }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    foreach ($c in $candidates) {
        $bt = Join-Path $c 'build-tools'
        if (Test-Path $bt) {
            $signer = Get-ChildItem $bt -Directory |
                Sort-Object Name -Descending |
                ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } |
                Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($signer) { return $signer }
        }
    }
    return $null
}

$apksigner = Find-ApkSigner
if (-not $apksigner) { Fail '找不到 apksigner，请确认 Android SDK build-tools 已安装' }
Write-Ok "apksigner: $apksigner"

# ------------------------------------------------------- 签名轮换
for ($i = 0; $i -lt $apks.Count; $i++) {
    $apk      = $apks[$i]
    $apkPath  = $apk.FullName
    Write-Step "签名轮换: $($apk.Name)"
    Write-Host "    size: $([math]::Round(([double]$apk.Length) / 1MB, 2)) MB"

    if (-not $rotationEnabled) {
        Write-Warn2 '未配置 legacyStoreFile / lineageFile，跳过签名轮换'
        Write-Warn2 '（<= v1.15.0 的老用户将无法覆盖安装，只能卸载重装）'
        continue
    }

    $signed = Join-Path $apk.DirectoryName ($apk.BaseName + '-rotated.apk')
    Remove-Item $signed -ErrorAction SilentlyContinue

    # 判断产物是否已带轮换签名：
    # 已轮换 -> v3 用 upload 密钥签名，v2 由 lineage 里最早的 debug 密钥签名，
    #           所以只看 API 28+ 时是 v3=true / v2=false；
    # 未轮换（gradle 只用 upload 密钥签）-> API 28+ 同时存在 v2 和 v3。
    $probeArgs = @('verify', '--print-certs', '-v', '--min-sdk-version', '28', $apkPath)
    $probe = (& $apksigner $probeArgs 2>&1 | Out-String)
    $probeV3 = $probe -match 'Verified using v3 scheme \(APK Signature Scheme v3\):\s*true'
    $probeV2 = $probe -match 'Verified using v2 scheme \(APK Signature Scheme v2\):\s*true'
    if ($probeV3 -and -not $probeV2) {
        Write-Ok '产物已带轮换签名，跳过重新签名'
        continue
    }

    & $apksigner sign `
        --ks $legacyKs --ks-key-alias $legacyAlias --ks-pass "pass:$legacyStore" --key-pass "pass:$legacyKeyPass" `
        --next-signer `
        --ks $uploadKs --ks-key-alias $uploadAlias --ks-pass "pass:$uploadStore" --key-pass "pass:$uploadKey" `
        --lineage $lineageFile `
        --min-sdk-version 24 --rotation-min-sdk-version 24 `
        --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false `
        --out $signed $apkPath

    if ($LASTEXITCODE -ne 0) { Fail "apksigner 轮换签名失败（exit $LASTEXITCODE）" }
    Move-Item $signed $apkPath -Force
    Write-Ok '已写入 v3 签名轮换 lineage（debug -> upload）'

    $sha1 = (Get-FileHash $apkPath -Algorithm SHA1).Hash.ToLower()
    Set-Content -Path "$apkPath.sha1" -Value $sha1 -NoNewline
}

# ------------------------------------------------------- 自检
Write-Step '签名自检'
$verifyScript = Join-Path $PSScriptRoot 'verify-signing.ps1'
if (Test-Path $verifyScript) {
    & $verifyScript -ApkDir $OutputDir
    if ($LASTEXITCODE -ne 0) { Fail '签名自检未通过' }
} else {
    Write-Warn2 '未找到 verify-signing.ps1，跳过自检'
}

# ------------------------------------------------------- 归档
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
foreach ($apk in $apks) {
    $target = Join-Path $ReleaseDir "zoosy-v$Version.apk"
    Copy-Item $apk.FullName $target -Force
    Write-Ok "已归档: release/zoosy-v$Version.apk"
}

Write-Host "`n完成。发布步骤：" -ForegroundColor Cyan
Write-Host "  1. 上传 release/zoosy-v$Version.apk 到网盘，更新 version.json 的 url"
Write-Host "  2. 提交并推送到 GitHub（origin: theohowie/zoosy, update: theohowie/zoosy-update）"
