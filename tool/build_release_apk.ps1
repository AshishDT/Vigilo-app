$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $projectRoot

# Keep the full Material icon font in release APKs to avoid garbled or missing glyphs.
& flutter build apk --release --no-tree-shake-icons @args
