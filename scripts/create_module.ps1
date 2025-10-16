# ============================================================
# create_module.ps1 (Fixed Path Logic Version)
# ============================================================

param (
    [string]$ModuleName,
    [string]$CustomMain
)

$ErrorActionPreference = "Stop"
$ProjectType = "console"
$Framework = "net8.0"

# ------------------------------
# Validate and normalize module name
# ------------------------------
if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    Write-Host "Error: ModuleName cannot be empty!" -ForegroundColor Red
    exit 1
}
if ($ModuleName -notmatch '^Module\.') {
    $ModuleName = "Module.$ModuleName"
}

if ($CustomMain -eq "") {
    $CustomMain = $ModuleName
}

# Capitalize first letter of each part
function Capitalize-EachPart($input) {
    $parts = $input -split '\.'
    $resultParts = @()

    foreach ($part in $parts) {
        $subs = $part -split '_'
        $fixedSubs = @()
        foreach ($sub in $subs) {
            if ($sub.Length -gt 0) {
                if ($sub.Length -eq 1) {
                    $fixedSubs += $sub.ToUpper()
                } else {
                    $fixedSubs += ($sub.Substring(0,1).ToUpper() + $sub.Substring(1, $sub.Length - 1).ToLower())
                }
            }
        }
        $resultParts += ($fixedSubs -join '_')
    }
    return ($resultParts -join '.')
}

$ModuleName = Capitalize-EachPart $ModuleName

if (-not $CustomMain) {
    $CustomMain = ($ModuleName.Split('.')[-1])
}

if ($CustomMain.Length -eq 1) {
    $ClassName = $CustomMain.ToUpper()
} else {
    $ClassName = ($CustomMain.Substring(0,1).ToUpper() + $CustomMain.Substring(1, $CustomMain.Length - 1))
}

# ------------------------------
# Find CSharpTeachingSolution directory
# ------------------------------
function Find-SolutionRoot {
    param([string]$StartPath)
    
    $current = $StartPath
    $maxDepth = 10  # Prevent infinite loop
    $depth = 0
    
    while ($depth -lt $maxDepth) {
        $folderName = Split-Path $current -Leaf
        
        # Found target directory
        if ($folderName -eq "CSharpTeachingSolution") {
            return $current
        }
        
        # Reached root directory
        $parent = Split-Path $current -Parent
        if ($parent -eq $null -or $parent -eq $current) {
            break
        }
        
        $current = $parent
        $depth++
    }
    
    return $null
}

$CurrentDir = Get-Location
$SolutionRoot = Find-SolutionRoot $CurrentDir

if ($SolutionRoot -eq $null) {
    Write-Host "Error: Cannot find CSharpTeachingSolution directory!" -ForegroundColor Red
    Write-Host "Current location: $CurrentDir" -ForegroundColor Yellow
    Write-Host "Please run this script from within the CSharpTeachingSolution directory or its subdirectories." -ForegroundColor Yellow
    exit 1
}

$TargetPath = Join-Path $SolutionRoot $ModuleName

Write-Host "Solution Root: $SolutionRoot" -ForegroundColor Cyan
Write-Host "Creating module: $TargetPath" -ForegroundColor Cyan

# ------------------------------
# Create directory structure
# ------------------------------
try {
    New-Item -ItemType Directory -Force -Path "$TargetPath\src" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TargetPath\test" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TargetPath\build" | Out-Null
} catch {
    Write-Host "Error creating directories: $_" -ForegroundColor Red
    exit 1
}

$OriginalLocation = Get-Location
Set-Location $TargetPath

# ------------------------------
# Create .csproj file
# ------------------------------
$CsprojFile = "$ModuleName.csproj"
Write-Host "Generating project file: $CsprojFile" -ForegroundColor Yellow

$Csproj = @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>$Framework</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$ModuleName</AssemblyName>
    <OutputPath>build\</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$ModuleName.$ClassName</StartupObject>
  </PropertyGroup>

  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="src\**\*.cs" />
    <Compile Include="test\**\*.cs" />
  </ItemGroup>

  <ItemGroup>
    <PackageReference Include="xunit" Version="2.8.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
  </ItemGroup>

</Project>
"@
Set-Content -Path $CsprojFile -Value $Csproj -Encoding UTF8

# ------------------------------
# Create main class file
# ------------------------------
Write-Host "Adding default main class file" -ForegroundColor Yellow

$MainPath = "src\$CustomMain.cs"
$MainCode = @"
using System;

namespace $ModuleName
{
    public class $ClassName
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("Hello from $ModuleName module!");
        }
    }
}
"@
Set-Content -Path $MainPath -Value $MainCode -Encoding UTF8

# ------------------------------
# Create test file
# ------------------------------
Write-Host "Adding test code" -ForegroundColor Yellow

$TestCode = @"
using System;
using Xunit;
using System.Diagnostics;

namespace $ModuleName.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            var sw = Stopwatch.StartNew();
            $ClassName.Main(Array.Empty<string>());
            sw.Stop();
            Assert.True(true);
            Console.WriteLine(`$"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@
Set-Content -Path "test\test.cs" -Value $TestCode -Encoding UTF8

# ------------------------------
# Completion message
# ------------------------------
Write-Host "`nModule $ModuleName created successfully!" -ForegroundColor Green
Write-Host "Location: $TargetPath" -ForegroundColor Cyan


code $TargetPath

