param (
    [string]$MODULE_NAME,
    [string]$CUSTOM_MAIN
)

# ------------------------------
# 参数检查
# ------------------------------
$PROJECT_TYPE = "web server"
$FRAMEWORK = "net8.0"

if ([string]::IsNullOrWhiteSpace($MODULE_NAME)) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <module_name>"
    exit 1
}

# 如果不是 Module.* 格式，自动加上前缀
if ($MODULE_NAME -notmatch '^Web\.') {
    $MODULE_NAME = "Web.$MODULE_NAME"
}

# 如果没有指定 CUSTOM_MAIN，则使用模块名最后一段
if ([string]::IsNullOrWhiteSpace($CUSTOM_MAIN)) {
    $CUSTOM_MAIN = ($MODULE_NAME -split '\.')[-1]
}

# ------------------------------
# 首字母大写（只处理最后一段）
# ------------------------------
$parts = $MODULE_NAME -split '\.'
$last = $parts[-1]
$last = $last.Substring(0,1).ToUpper() + $last.Substring(1)
$parts[-1] = $last
$MODULE_NAME = ($parts -join '.')

$CUSTOM_MAIN = $CUSTOM_MAIN.Substring(0,1).ToUpper() + $CUSTOM_MAIN.Substring(1)

# 类名和文件名保持一致
$CLASS_NAME = $CUSTOM_MAIN

# ------------------------------
# 创建模块目录
# ------------------------------
Write-Host "📂 Creating module directory: $MODULE_NAME"

New-Item -ItemType Directory -Path $MODULE_NAME -Force | Out-Null
New-Item -ItemType Directory -Path "$MODULE_NAME/src" -Force | Out-Null
New-Item -ItemType Directory -Path "$MODULE_NAME/test" -Force | Out-Null
New-Item -ItemType Directory -Path "$MODULE_NAME/build" -Force | Out-Null

Set-Location $MODULE_NAME

# ------------------------------
# 创建 csproj
# ------------------------------
Write-Host "🛠 Creating $PROJECT_TYPE project: $MODULE_NAME"

$CS_PROJ = "$MODULE_NAME.csproj"

@"
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>$FRAMEWORK</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$MODULE_NAME</AssemblyName>
    <OutputPath>build/</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$MODULE_NAME.$CLASS_NAME</StartupObject>
    <RunArguments>--urls http://0.0.0.0:8080</RunArguments>
  </PropertyGroup>

  <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <!-- 包含主代码和测试代码 -->
  <ItemGroup>
    <Compile Include="src\**\*.cs" />
    <Compile Include="test\**\*.cs" />
  </ItemGroup>

  <!-- 使用 xUnit 测试框架 -->
  <ItemGroup>
    <PackageReference Include="xunit" Version="2.8.0" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" />
  </ItemGroup>

</Project>
"@ | Set-Content $CS_PROJ -Encoding UTF8

# ------------------------------
# 添加主代码
# ------------------------------
Write-Host "🛠 Adding default module code"

$MAIN_PATH = "src/$CUSTOM_MAIN.cs"

@"
using System;
using System.IO;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
namespace $MODULE_NAME
{
    public class $CLASS_NAME
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
"@ | Set-Content $MAIN_PATH -Encoding UTF8

# ------------------------------
# 添加网页代码
# ------------------------------
Write-Host "🛠 Adding home.html"

@"
<!doctype html>
<html lang="zh-CN">
    <head>
        <meta charset="utf-8">
        <title>$MODULE_NAME API</title>
    </head>
    <body>
        <h1>$MODULE_NAME (Minimal API)</h1>
    </body>
</html>
"@ | Set-Content "src/home.html" -Encoding UTF8

# ------------------------------
# 添加基础测试
# ------------------------------
Write-Host "🛠 Adding test.cs"

@"
using System;
using Xunit;
using System.Diagnostics;
using $MODULE_NAME;

namespace $MODULE_NAME.Tests
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
            var result = $CLASS_NAME.LoadHtml(htmlPath);
            Console.WriteLine(result);
            sw.Stop();
            Assert.True(true); // 示例测试
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
"@ | Set-Content "test/test.cs" -Encoding UTF8

Write-Host "✅ Module $MODULE_NAME created successfully."

# 打开 VS Code
code .
