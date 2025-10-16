<#
================================================================
Module Auto-Generation Script (PowerShell Version)
Function: Create a new C# module project in the **parent directory** of the current folder
================================================================
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,      # Module name, e.g. Module.Hello or Hello

    [string]$CustomMain       # Optional main class name
)

# ------------------------------
# Environment settings
# ------------------------------
$ErrorActionPreference = "Stop"
$ProjectType = "console"
$Framework = "net8.0"

# ------------------------------
# Validate and normalize module name
# ------------------------------
if ($ModuleName -notmatch '^Module\.') {
    $ModuleName = "Module.$ModuleName"
}

# Capitalize each part of the module name (including underscores)
function Capitalize-EachPart($input) {
    $parts = $input -split '\.'
    $resultParts = @()

    foreach ($part in $parts) {
        $subs = $part -split '_'
        $fixedSubs = @()
        foreach ($sub in $subs) {
            if ($sub.Length -gt 0) {
                # 修复：检查长度避免 Substring 越界
                if ($sub.Length -eq 1) {
                    $fixedSubs += $sub.ToUpper()
                } else {
                    $fixedSubs += ($sub.Substring(0,1).ToUpper() + $sub.Substring(1).ToLower())
                }
            }
        }
        $resultParts += ($fixedSubs -join '_')
    }

    return ($resultParts -join '.')
}

$ModuleName = Capitalize-EachPart $ModuleName

# If no custom main class is provided, use the last part of the module name
if (-not $CustomMain) {
    $CustomMain = ($ModuleName.Split('.')[-1])
}

# Capitalize main class name
if ($CustomMain.Length -eq 1) {
    $ClassName = $CustomMain.ToUpper()
} else {
    $ClassName = ($CustomMain.Substring(0,1).ToUpper() + $CustomMain.Substring(1))
}

# ------------------------------
# Create module directory (in parent directory)
# ------------------------------
$CurrentDir = Get-Location
$CurrentFolderName = Split-Path $CurrentDir -Leaf

# Check if current directory is "CSharpTeachingSolution"
if ($CurrentFolderName -eq "CSharpTeachingSolution") {
    # If inside CSharpTeachingSolution, create directly inside it
    $TargetPath = Join-Path $CurrentDir $ModuleName
}
else {
    # Otherwise, create inside the parent directory
    $ParentDir = Split-Path $CurrentDir -Parent
    $TargetPath = Join-Path $ParentDir $ModuleName
}

Write-Host "Creating module directory: $TargetPath" -ForegroundColor Cyan

# 修复：使用 try-catch 处理目录创建
try {
    New-Item -ItemType Directory -Force -Path "$TargetPath/src" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TargetPath/test" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TargetPath/build" | Out-Null
} catch {
    Write-Host "Error creating directories: $_" -ForegroundColor Red
    exit 1
}

# 保存原始位置
$OriginalLocation = Get-Location
Set-Location $TargetPath

# ------------------------------
# Create .csproj file
# ------------------------------
$CsprojFile = "$ModuleName.csproj"
Write-Host "Generating project file: $CsprojFile" -ForegroundColor Yellow

# 修复：统一使用反斜杠作为路径分隔符
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

  <!-- Include main and test source files -->
  <ItemGroup>
    <Compile Include="src\**\*.cs" />
    <Compile Include="test\**\*.cs" />
  </ItemGroup>

  <!-- Test dependencies -->
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
# Add default main class file
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
# Add test file
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
            Assert.True(true); // Example test
            Console.WriteLine(`$"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@
Set-Content -Path "test\test.cs" -Value $TestCode -Encoding UTF8

# ------------------------------
# Completion message
# ------------------------------
Write-Host "`nModule $ModuleName has been successfully created." -ForegroundColor Green
Write-Host "Location: $TargetPath" -ForegroundColor Cyan

# ------------------------------
# Open in VS Code
# ------------------------------
try {
    code $TargetPath
} catch {
    Write-Host "Could not open VS Code. Please open manually: $TargetPath" -ForegroundColor Yellow
}

# 返回原始位置
Set-Location $OriginalLocation