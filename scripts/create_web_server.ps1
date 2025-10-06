<#
================================================================
📘 模块自动生成脚本（PowerShell 版）
功能：在当前目录的父目录中创建新的 C# Web 模块项目（Minimal API）
================================================================
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,         # 模块名，例如 Hello 或 Web.Hello

    [string]$CustomMain          # 可选主类名
)

# ------------------------------
# 环境设置
# ------------------------------
$ErrorActionPreference = "Stop"
$Framework = "net8.0"
$ProjectType = "web server"

# ------------------------------
# 模块名规范化
# ------------------------------
if ($ModuleName -notmatch '^Web\.') {
    $ModuleName = "Web.$ModuleName"
}

# 两个部分首字母大写
$ModuleParts = $ModuleName -split '\.'
$ModuleName = ($ModuleParts | ForEach-Object { 
    $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() 
}) -join '.'

if (-not $CustomMain) {
    $CustomMain = ($ModuleName.Split('.')[-1])
}

$ClassName = ($CustomMain.Substring(0,1).ToUpper() + $CustomMain.Substring(1))

# ------------------------------
# 创建模块目录（在父目录中）
# ------------------------------
$CurrentDir = Get-Location
$CurrentFolderName = Split-Path $CurrentDir -Leaf
# 判断当前目录是否为 "CsharpTeachingSolution"
if ($CurrentFolderName -eq "CSharpTeachingSolution") {
    # 如果当前目录是 CsharpTeachingSolution，就直接使用当前目录
    $TargetPath = Join-Path $CurrentDir $ModuleName
}
else {
    # 否则使用上一级目录
    $ParentDir = Split-Path $CurrentDir -Parent
    $TargetPath = Join-Path $ParentDir $ModuleName
}

Write-Host "在父目录创建模块目录: $TargetPath" -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "$TargetPath/src" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetPath/test" | Out-Null
New-Item -ItemType Directory -Force -Path "$TargetPath/build" | Out-Null

Set-Location $TargetPath

# ------------------------------
# 创建 csproj 文件
# ------------------------------
Write-Host "生成项目文件: $ModuleName.csproj" -ForegroundColor Yellow

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
# 添加默认主类文件
# ------------------------------
Write-Host "添加默认主类: $ClassName.cs" -ForegroundColor Yellow

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
# 添加网页文件
# ------------------------------
Write-Host "添加 home.html" -ForegroundColor Yellow

$Html = @"
<!doctype html>
<html lang="zh-CN">
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
# 添加测试文件
# ------------------------------
Write-Host "添加 test.cs" -ForegroundColor Yellow

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
            Assert.True(true); // 示例测试
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@
Set-Content -Path "test/test.cs" -Value $TestCode -Encoding UTF8

# ------------------------------
# 完成提示
# ------------------------------
Write-Host "`n 模块 $ModuleName 创建完成！" -ForegroundColor Green
Write-Host "路径：$TargetPath" -ForegroundColor Cyan

# ------------------------------
# 打开 VS Code
# ------------------------------
code $TargetPath
