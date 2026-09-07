#!/bin/bash
# ================================================================
# 🌐 Web 模块自动生成脚本
# 功能：在当前目录中创建一个新的 C# Web 模块项目
# ================================================================

set -e

# ------------------------------
# 参数检查
# ------------------------------
MODULE_NAME=$1       # 模块名，例如 Web.Hello
PROJECT_TYPE="web server"
FRAMEWORK="net8.0"
CUSTOM_MAIN=$2

if [[ -z "$MODULE_NAME" ]]; then
    echo "Usage: $0 <module_name>"
    echo "Example: $0 hello 或 $0 Web.Hello"
    exit 1
fi

# 若模块名未以 'Web.' 开头，则自动补齐
if [[ ! "$MODULE_NAME" =~ ^Web\. ]]; then
    MODULE_NAME="Web.$MODULE_NAME"
fi

# --------------------------------------------------
# 将模块名的每个部分首字母大写
# 例：web.demo_test → Web.Demo_Test
# --------------------------------------------------
function capitalize_each_part() {
    local input="$1"
    local result=""
    IFS='.' read -ra PARTS <<< "$input"
    for part in "${PARTS[@]}"; do
        IFS='_' read -ra SUBS <<< "$part"
        local fixed=""
        for sub in "${SUBS[@]}"; do
            fixed+="${sub^}_"
        done
        fixed="${fixed%_}"
        result+="${fixed}."
    done
    echo "${result%.}"
}

MODULE_NAME=$(capitalize_each_part "$MODULE_NAME")

# 若未指定自定义主类名，则取模块名最后一部分
if [[ -z "$CUSTOM_MAIN" ]]; then
    CUSTOM_MAIN="${MODULE_NAME##*.}"
fi

CLASS_NAME="${CUSTOM_MAIN^}"

# ------------------------------
# 创建模块目录
# ------------------------------
# 获取当前脚本所在路径
CURRENT_DIR=$(pwd)
# 获取当前文件夹名
CURRENT_FOLDER_NAME=$(basename "$CURRENT_DIR")
# 判断当前目录名
if [ "$CURRENT_FOLDER_NAME" = "CSharpTeachingSolution" ]; then
    TARGET_PATH="$CURRENT_DIR/$MODULE_NAME"
else
    PARENT_DIR=$(dirname "$CURRENT_DIR")
    TARGET_PATH="$PARENT_DIR/$MODULE_NAME"
fi

echo "Creating module directory: $MODULE_NAME"

mkdir -p "$TARGET_PATH/src"
mkdir -p "$TARGET_PATH/test"
mkdir -p "$TARGET_PATH/build"

cd "$MODULE_NAME"

# ------------------------------
# 创建 csproj
# ------------------------------
echo "🛠 Creating $PROJECT_TYPE project: $MODULE_NAME"

CS_PROJ="$MODULE_NAME.csproj"

cat > "$CS_PROJ" <<EOF
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

  <PropertyGroup Condition=" '$(Configuration)' == 'Debug' ">
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <!-- 包含主代码和测试代码 -->
  <ItemGroup>
    <Compile Include="src\\**\\*.cs" />
    <Compile Include="test\\**\\*.cs" />
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
EOF

# ------------------------------
# 添加主代码
# ------------------------------
echo "Adding default module code"

MAIN_PATH="src/$CLASS_NAME.cs"

cat > "$MAIN_PATH" <<EOF
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
EOF

# ------------------------------
# 添加网页代码
# ------------------------------
echo "Adding home.html"

cat > "src/home.html" <<EOF
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
EOF

# ------------------------------
# 添加基础测试
# ------------------------------
echo "Adding test.cs"

cat > "test/test.cs" <<EOF
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
EOF

# ------------------------------
# 完成提示
# ------------------------------
echo "Module $MODULE_NAME created successfully."
echo "Path: $(pwd)"

# ------------------------------
# 打开 VS Code
# ------------------------------
code .
