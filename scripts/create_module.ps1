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

try {
    code $TargetPath
} catch {
    Write-Host "Could not open VS Code automatically." -ForegroundColor Yellow
}

Set-Location $OriginalLocation


# ============================================================
# create_web_server.ps1 (Fixed Path Logic Version)
# ============================================================

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    [string]$CustomMain
)

$ErrorActionPreference = "Stop"
$Framework = "net8.0"

# ------------------------------
# Normalize module name
# ------------------------------
if ($ModuleName -notmatch '^Web\.') {
    $ModuleName = "Web.$ModuleName"
}

if ($CustomMain -eq "") {
    $CustomMain = $ModuleName
}

$ModuleParts = $ModuleName -split '\.'
$ModuleName = ($ModuleParts | ForEach-Object { 
    if ($_.Length -eq 1) {
        $_.ToUpper()
    } else {
        $_.Substring(0,1).ToUpper() + $_.Substring(1, $_.Length - 1).ToLower()
    }
}) -join '.'

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
    $maxDepth = 10
    $depth = 0
    
    while ($depth -lt $maxDepth) {
        $folderName = Split-Path $current -Leaf
        
        if ($folderName -eq "CSharpTeachingSolution") {
            return $current
        }
        
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
    exit 1
}

$TargetPath = Join-Path $SolutionRoot $ModuleName

Write-Host "Solution Root: $SolutionRoot" -ForegroundColor Cyan
Write-Host "Creating web module: $TargetPath" -ForegroundColor Cyan

# ------------------------------
# Create directories
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
Write-Host "Generating project file" -ForegroundColor Yellow

$Csproj = @"
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>$Framework</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$ModuleName</AssemblyName>
    <OutputPath>build\</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$ModuleName.$ClassName</StartupObject>
    <RunArguments>--urls http://0.0.0.0:8080</RunArguments>
  </PropertyGroup>

  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="src\**\*.cs" />
    <Compile Include="test\**\*.cs" />
    <Content Include="src\*.html">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
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
Set-Content -Path "$ModuleName.csproj" -Value $Csproj -Encoding UTF8

# ------------------------------
# Create main class
# ------------------------------
Write-Host "Adding main class" -ForegroundColor Yellow

$MainCode = @"
using System;
using System.IO;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace $ModuleName
{
    public class $ClassName
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            var app = builder.Build();
            
            string htmlPath = FindHtmlFile("home.html");
            app.MapGet("/", () => LoadHtml(htmlPath));
            
            Console.WriteLine(`$"Server starting at http://localhost:8080");
            app.Run();
        }

        private static string FindHtmlFile(string fileName)
        {
            string baseDir = AppContext.BaseDirectory;
            
            string[] possiblePaths = new[]
            {
                Path.Combine(baseDir, fileName),
                Path.Combine(baseDir, "src", fileName),
                Path.Combine(baseDir, "..", "..", "src", fileName),
                Path.Combine(baseDir, "..", "..", "..", "src", fileName)
            };

            foreach (var path in possiblePaths)
            {
                string fullPath = Path.GetFullPath(path);
                if (File.Exists(fullPath))
                {
                    return fullPath;
                }
            }

            return Path.GetFullPath(possiblePaths[2]);
        }

        public static IResult LoadHtml(string filePath)
        {
            if (!File.Exists(filePath))
            {
                return Results.NotFound(`$"HTML not found: {filePath}");
            }

            string htmlContent = File.ReadAllText(filePath);
            return Results.Content(htmlContent, "text/html");
        }
    }
}
"@
Set-Content -Path "src\$CustomMain.cs" -Value $MainCode -Encoding UTF8

# ------------------------------
# Create HTML file
# ------------------------------
Write-Host "Adding home.html" -ForegroundColor Yellow

$Html = @"
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <title>$ModuleName</title>
    </head>
    <body>
        <h1>$ModuleName</h1>
        <p>Web server is running!</p>
    </body>
</html>
"@
Set-Content -Path "src\home.html" -Value $Html -Encoding UTF8

# ------------------------------
# Create test file
# ------------------------------
Write-Host "Adding test" -ForegroundColor Yellow

$TestCode = @"
using System;
using System.IO;
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
            
            string baseDir = AppContext.BaseDirectory;
            string htmlPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "src", "home.html"));
            
            var result = $ClassName.LoadHtml(htmlPath);
            
            sw.Stop();
            Assert.NotNull(result);
            Console.WriteLine(`$"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@
Set-Content -Path "test\test.cs" -Value $TestCode -Encoding UTF8

# ------------------------------
# Completion message
# ------------------------------
Write-Host "`nWeb module $ModuleName created successfully!" -ForegroundColor Green
Write-Host "Location: $TargetPath" -ForegroundColor Cyan

code $TargetPath
