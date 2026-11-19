$ErrorActionPreference = 'Stop'
$nativeRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $nativeRoot '.build'
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$binary = Join-Path $buildRoot 'core_test.exe'
& gcc -std=c11 -O2 -Wall -Wextra -Werror (Join-Path $nativeRoot 'Core/SSMatcher.c') (Join-Path $nativeRoot 'tests/core_test.c') -o $binary
if ($LASTEXITCODE -ne 0) { throw 'Native core compilation failed.' }
& $binary
if ($LASTEXITCODE -ne 0) { throw 'Native core tests failed.' }
& python (Join-Path $PSScriptRoot 'verify-project.py')
if ($LASTEXITCODE -ne 0) { throw 'Project verification failed.' }
