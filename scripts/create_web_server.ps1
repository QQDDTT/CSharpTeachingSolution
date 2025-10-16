<#
================================================================
Module Auto-Generation Script (PowerShell Version)
Function: Create a new C# Web module project (Minimal API) 
          in the parent directory of the current folder.
================================================================
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,         # Module name, e.g. Hello or Web.Hello

    [string]$CustomMain          # Optional main class name
)

# ------------------------------
# Environment settings
# ------------------------------
$ErrorActionPreference = "Stop"
$Framework = "net8.0"
$ProjectType = "web server"

# ------------------------------
# Normalize module name
# ------------------------------
if ($ModuleName -notmatch '^Web\.') {
    $ModuleName = "Web.$ModuleName"
}
if ($CustomMain -eq "") {
    $CustomMain = $ModuleName
}

# Capitalize both parts of the name
$ModuleParts = $ModuleName -split '\.'
$ModuleName = ($ModuleParts | ForEach-Object { 
    $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() 
}) -join '.'

if (-not $CustomMain) {
    $CustomMain = ($ModuleName.Split('.')[-1])
}

$ClassName = ($CustomMain.Substring(0,1).ToUpper() + $CustomMain.Substring(1))

# ------------------------------
# Create module directory (in parent directory)
# ------------------------------
$CurrentDir = Get-Location
$CurrentFolderName = Split-Path $CurrentDir -Leaf
# Check if current directory is "CSharpTeachingSolution"
if ($CurrentFolderName -eq "CSharpTeachingSolution") {
    # If the current directory is CSharpTeachingSolution, create inside it
    $TargetPath = Join-Path $CurrentDir $ModuleName
}
else {
    # Otherwise, create inside the parent directory
    $ParentDir = Split-Path $CurrentDir -Parent
    $TargetPath = Join-Path $ParentDir $ModuleName
}

Write-Host "Creating module directory in parent folder: $TargetPath" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "$TargetPath/src" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetPath/test" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetPath/build" | Out-Null

Set-Location $TargetPath

# ------------------------------
# Create .csproj file
# ------------------------------
Write-Host "Generating project file: $ModuleName.csproj" -ForegroundColor Yellow

$Csproj = @"
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>$Framework</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$ModuleName</AssemblyName>
    <OutputPath>build/</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$ModuleName.$ClassName</StartupObject>
    <RunArguments>--urls http://0.0.0.0:8080</RunArguments>
  </PropertyGroup>

  <PropertyGroup Condition=" '$(Configuration)' == 'Debug' ">
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
Set-Content -Path "$ModuleName.csproj" -Value $Csproj -Encoding UTF8

# ------------------------------
# Add default main class
# ------------------------------
Write-Host "Adding default main class: $ClassName.cs" -ForegroundColor Yellow

$MainCode = @"
using System;
using System.IO;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;

namespace $ModuleName
{
    public class $ClassName
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            var app = builder.Build();  
            string baseDir = AppContext.BaseDirectory;
            string relativePath = "src/home.html";
            string htmlPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", relativePath));
            app.MapGet("/", () => LoadHtml(htmlPath));
            app.Run();
        }

        public static IResult LoadHtml(string filePath)
        {
            if (!File.Exists(filePath))
            {
                return Results.NotFound($"HTML file not found: {filePath}");
            }

            string htmlContent = File.ReadAllText(filePath);
            return Results.Content(htmlContent, "text/html");
        }
    }
}
"@
Set-Content -Path "src/$CustomMain.cs" -Value $MainCode -Encoding UTF8

# ------------------------------
# Add default web page
# ------------------------------
Write-Host "Adding home.html" -ForegroundColor Yellow

$Html = @"
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <title>$ModuleName API</title>
    </head>
    <body>
        <h1>$ModuleName (Minimal API)</h1>
    </body>
</html>
"@
Set-Content -Path "src/home.html" -Value $Html -Encoding UTF8

# ------------------------------
# Add test file
# ------------------------------
Write-Host "Adding test.cs" -ForegroundColor Yellow

$TestCode = @"
using System;
using Xunit;
using System.Diagnostics;
using $ModuleName;

namespace $ModuleName.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            var sw = Stopwatch.StartNew();
            string baseDir = AppContext.BaseDirectory;
            string relativePath = "src/home.html";
            string htmlPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", relativePath));
            var result = $ClassName.LoadHtml(htmlPath);
            Console.WriteLine(result);
            sw.Stop();
            Assert.True(true); // Example test
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@
Set-Content -Path "test/test.cs" -Value $TestCode -Encoding UTF8

# ------------------------------
# Completion message
# ------------------------------
Write-Host "`n Module $ModuleName created successfully!" -ForegroundColor Green
Write-Host "Location: $TargetPath" -ForegroundColor Cyan

# ------------------------------
# Open project in VS Code
# ------------------------------
code $TargetPath
