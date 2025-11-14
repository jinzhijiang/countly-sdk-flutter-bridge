#######################################################################
# ⚠️ Execution Policy (first-time PowerShell)
#
# If you see the error:
#   "execution of scripts is disabled on this system"
#
# Run ONE of the following:
#
# Option A — enable script execution for current user:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
# Option B — run the script without changing policy:
#   powershell -ExecutionPolicy Bypass -File .\scripts\init-ios-sdk.ps1
#
#######################################################################
Param(
    [string]$Tag = "25.4.7"
)

# CONFIGURATION
$SubmodulePath = "ios/Classes/countly-sdk-ios"
$MainSparseFile = "..\..\..\scripts\sparse-checkout.list"

Write-Host "🔧 Initializing Countly iOS SDK submodule..."
Write-Host "   Tag: $Tag"
Write-Host "   Path: $SubmodulePath"
Write-Host ""

# Ensure submodule exists
git submodule update --init --recursive $SubmodulePath

# Enter submodule directory
if (-Not (Test-Path $SubmodulePath)) {
    Write-Host "❌ Failed to enter submodule path."
    exit 1
}

Set-Location $SubmodulePath

# Fetch & checkout tag
Write-Host "📥 Checking out tag $Tag..."
git fetch --all --tags
$checkout = git checkout $Tag 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tag not found: $Tag"
    exit 1
}

# Ensure sparse-checkout.list exists in repo root
if (-Not (Test-Path $MainSparseFile)) {
    Write-Host "❌ Missing sparse-checkout rules at: scripts/sparse-checkout.list"
    exit 1
}

Write-Host "🧹 Applying sparse-checkout rules from: scripts/sparse-checkout.list"

# Initialize sparse checkout (non-cone mode)
git sparse-checkout init --no-cone

# Get internal sparse-checkout file path
$InfoPath = git rev-parse --git-path info
$SparseFile = Join-Path $InfoPath "sparse-checkout"

# Copy sparse rules into internal Git directory
Copy-Item $MainSparseFile $SparseFile -Force

# Apply sparse rules
git read-tree -mu HEAD

Write-Host ""
Write-Host "✅ Countly iOS SDK initialized"
Write-Host "   → Tag: $Tag"
Write-Host "   → Sparse checkout applied using scripts/sparse-checkout.list"
