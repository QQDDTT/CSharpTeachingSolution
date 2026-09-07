#!/bin/bash
# ================================================================
# 模块自动生成脚本
# 功能：在当前目录的【父目录】中创建一个新的 C# 模块项目
# ================================================================

set -e  # 遇到任何错误立即退出

# ------------------------------
# 参数检查与变量设置
# ------------------------------
MODULE_NAME=$1       # 模块名，例如 Module.Hello 或 Hello
PROJECT_TYPE="console"
FRAMEWORK="net8.0"
CUSTOM_MAIN=$2        # 可选主类名

if [[ -z "$MODULE_NAME" ]]; then
    echo "用法：$0 <module_name> [MainClass]"
    echo "示例：$0 Hello"
    exit 1
fi

# 若模块名未以 'Module.' 开头，则自动补齐
if [[ "$MODULE_NAME" != Module.* ]]; then
    MODULE_NAME="Module.$MODULE_NAME"
fi

# --------------------------------------------------
# 将模块名的每个部分首字母大写
# 例：module.sub_name → Module.Sub_Name
# --------------------------------------------------
function capitalize_each_part() {
    local input="$1"
    local result=""
    IFS='.' read -ra PARTS <<< "$input"
    for part in "${PARTS[@]}"; do
        # 将下划线分割的部分也首字母大写
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

# 在开始阶段就将主类名首字母大写
CLASS_NAME="${CUSTOM_MAIN^}"

# ------------------------------
# 创建模块目录（在父目录中）
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

echo "Creating module directory: $TARGET_PATH"

mkdir -p "$TARGET_PATH/src"
mkdir -p "$TARGET_PATH/test"
mkdir -p "$TARGET_PATH/build"

cd "$TARGET_PATH"

# ------------------------------
# 🛠 创建 csproj 文件
# ------------------------------
CS_PROJ="$MODULE_NAME.csproj"
CLASS_NAME="${CUSTOM_MAIN^}"  # 首字母大写

echo "生成项目文件: $CS_PROJ"

cat > "$CS_PROJ" <<EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>$FRAMEWORK</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$MODULE_NAME</AssemblyName>
    <OutputPath>build/</OutputPath>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <StartupObject>$MODULE_NAME.$CLASS_NAME</StartupObject>
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
EOF

# ------------------------------
# 添加默认主代码
# ------------------------------
echo "添加默认主类文件"

MAIN_PATH="src/$CUSTOM_MAIN.cs"

cat > "$MAIN_PATH" <<EOF
using System;
namespace $MODULE_NAME
{
    public class $CLASS_NAME
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("Hello from $MODULE_NAME module!");
        }
    }
}
EOF

# ------------------------------
# 添加基础测试代码
# ------------------------------
echo "添加测试代码"

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
            $CLASS_NAME.Main(Array.Empty<string>());
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
echo "模块 $MODULE_NAME 创建完成。"
echo "路径：$TARGET_PATH"

# ------------------------------
# 打开 VS Code
# ------------------------------
code "$TARGET_PATH"
