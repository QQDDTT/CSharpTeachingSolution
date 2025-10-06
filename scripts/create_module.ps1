<#
================================================================
模块自动生成脚本（PowerShell 版）
功能：在当前目录的【父目录】中创建一个新的 C# 模块项目
================================================================
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,      # 模块名，例如 Module.Hello 或 Hello

    [string]$CustomMain       # 可选主类名
)

# ------------------------------
# 环境设置
# ------------------------------
$ErrorActionPreference = "Stop"
$ProjectType = "console"
$Framework = "net8.0"

# ------------------------------
# 模块名检查与标准化
# ------------------------------
if ($ModuleName -notmatch '^Module\.') {
    $ModuleName = "Module.$ModuleName"
}

# 将模块名的每个部分首字母大写（含下划线）
function Capitalize-EachPart($input) {
    $parts = $input -split '\.'
    $resultParts = @()

    foreach ($part in $parts) {
        $subs = $part -split '_'
        $fixedSubs = @()
        foreach ($sub in $subs) {
            if ($sub.Length -gt 0) {
                $fixedSubs += ($sub.Substring(0,1).ToUpper() + $sub.Substring(1).ToLower())
            }
        }
        $resultParts += ($fixedSubs -join '_')
    }

    return ($resultParts -join '.')
}

$ModuleName = Capitalize-EachPart $ModuleName

# 若未指定自定义主类名，则取模块名最后一部分
if (-not $CustomMain) {
    $CustomMain = ($ModuleName.Split('.')[-1])
}

# 主类名首字母大写
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
$CsprojFile = "$ModuleName.csproj"
Write-Host "生成项目文件: $CsprojFile" -ForegroundColor Yellow

$Csproj = @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>$Framework</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$ModuleName</AssemblyName>
    <OutputPath>build/</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$ModuleName.$ClassName</StartupObject>
  </PropertyGroup>

  <PropertyGroup Condition=" '$(Configuration)' == 'Debug' ">
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <!-- 包含主代码与测试代码 -->
  <ItemGroup>
    <Compile Include="src\\**\\*.cs" />
    <Compile Include="test\\**\\*.cs" />
  </ItemGroup>

  <!-- 测试依赖项 -->
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
# 添加默认主类文件
# ------------------------------
Write-Host "添加默认主类文件" -ForegroundColor Yellow

$MainPath = "src/$CustomMain.cs"
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
# 添加测试文件
# ------------------------------
Write-Host "添加测试代码" -ForegroundColor Yellow

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
            $ClassName.Main(Array.Empty<string>());
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
Write-Host "`n模块 $ModuleName 创建完成。" -ForegroundColor Green
Write-Host "路径：$TargetPath" -ForegroundColor Cyan

# ------------------------------
# 打开 VS Code
# ------------------------------
code $TargetPath
