@echo off
setlocal enabledelayedexpansion

REM ------------------------------
REM 参数检查
REM ------------------------------
set MODULE_NAME=%1
set PROJECT_TYPE=console
set FRAMEWORK=net8.0
set CUSTOM_MAIN=%2

if "%MODULE_NAME%"=="" (
    echo Usage: %~nx0 ^<module_name^>
    exit /b 1
)

REM 如果不是 Module.* 格式，自动加上前缀
echo %MODULE_NAME% | findstr /b "Module." >nul
if errorlevel 1 (
    set MODULE_NAME=Module.%MODULE_NAME%
)

REM 如果没有指定 CUSTOM_MAIN，则使用模块名最后一段
if "%CUSTOM_MAIN%"=="" (
    for %%A in (%MODULE_NAME:.= %) do set LAST_PART=%%A
    set CUSTOM_MAIN=!LAST_PART!
)

REM ------------------------------
REM 首字母大写
REM ------------------------------
for /f %%C in ('powershell -Command "[string]'%CUSTOM_MAIN%'.Substring(0,2).ToUpper() + '%CUSTOM_MAIN%'.Substring(1)" do set CLASS_NAME=%%C)

REM ------------------------------
REM 创建模块目录
REM ------------------------------
echo 📂 Creating module directory: %MODULE_NAME%

mkdir "%MODULE_NAME%"
mkdir "%MODULE_NAME%\src"
mkdir "%MODULE_NAME%\test"
mkdir "%MODULE_NAME%\build"

cd "%MODULE_NAME%"

REM ------------------------------
REM 创建 csproj
REM ------------------------------
echo 🛠 Creating %PROJECT_TYPE% project: %MODULE_NAME%

set CS_PROJ=%MODULE_NAME%.csproj

set CLASS_NAME=%CLASS_NAME%%CUSTOM_MAIN:~1%

(
echo ^<Project Sdk="Microsoft.NET.Sdk"^>
echo.
echo   ^<PropertyGroup^>
echo     ^<TargetFramework^>%FRAMEWORK%^</TargetFramework^>
echo     ^<ImplicitUsings^>enable^</ImplicitUsings^>
echo     ^<Nullable^>enable^</Nullable^>
echo     ^<AssemblyName^>%MODULE_NAME%^</AssemblyName^>
echo     ^<OutputPath^>build/^</OutputPath^>
echo     ^<EnableDefaultCompileItems^>false^</EnableDefaultCompileItems^>
echo     ^<StartupObject^>%MODULE_NAME%.%CLASS_NAME%^</StartupObject^>
echo   ^</PropertyGroup^>
echo.
echo   ^<PropertyGroup Condition=" '$(Configuration)' == 'Debug' " ^>
echo     ^<OutputType^>Exe^</OutputType^>
echo   ^</PropertyGroup^>
echo.
echo   ^<!-- 包含主代码和测试代码 --^>
echo   ^<ItemGroup^>
echo     ^<Compile Include="src\**\*.cs" /^>
echo     ^<Compile Include="test\**\*.cs" /^>
echo   ^</ItemGroup^>
echo.
echo   ^<!-- 使用 xUnit 测试框架 --^>
echo   ^<ItemGroup^>
echo     ^<PackageReference Include="xunit" Version="2.8.0" /^>
echo     ^<PackageReference Include="xunit.runner.visualstudio" Version="2.8.0"^>
echo       ^<PrivateAssets^>all^</PrivateAssets^>
echo       ^<IncludeAssets^>runtime; build; native; contentfiles; analyzers; buildtransitive^</IncludeAssets^>
echo     ^</PackageReference^>
echo     ^<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1" /^>
echo   ^</ItemGroup^>
echo.
echo ^</Project^>
) > %CS_PROJ%

REM ------------------------------
REM 添加主代码
REM ------------------------------
echo 🛠 Adding default module code

set MAIN_PATH=src\%CUSTOM_MAIN%.cs

(
echo using System;
echo namespace %MODULE_NAME%
echo {
echo     public class %CLASS_NAME%
echo     {
echo         public static void Main(string[] args)
echo         {
echo             Console.WriteLine("Hello from %MODULE_NAME% module!");
echo         }
echo     }
echo }
) > %MAIN_PATH%

REM ------------------------------
REM 添加基础测试
REM ------------------------------
echo 🛠 Adding test.cs

(
echo using System;
echo using Xunit;
echo using System.Diagnostics;
echo using %MODULE_NAME%;
echo.
echo namespace %MODULE_NAME%.Tests
echo {
echo     public class TestModule
echo     {
echo         [Fact]
echo         public void RunTest()
echo         {
echo             var sw = Stopwatch.StartNew();
echo             %CLASS_NAME%.Main(Array.Empty^<string^>^());
echo             sw.Stop();
echo             Assert.True(true); // 示例测试
echo             Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
echo         }
echo     }
echo }
) > test\test.cs

echo ✅ Module %MODULE_NAME% created successfully.

REM 打开 VS Code
code .
