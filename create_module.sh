#!/bin/bash

set -e

# ------------------------------
# 参数检查
# ------------------------------
MODULE_NAME=$1       # 模块名，例如 Module.Hello
PROJECT_TYPE="console"
FRAMEWORK="net8.0"
CUSTOM_MAIN=$2

if [[ -z "$MODULE_NAME" ]]; then
    echo "Usage: $0 <module_name>"
    exit 1
fi

if [[ "$MODULE_NAME" != "Module.*"  ]]; then
    MODULE_NAME="Module.$MODULE_NAME"
fi

if [[ -z "$CUSTOM_MAIN" ]]; then
    CUSTOM_MAIN="${MODULE_NAME##*.}"
fi


# ------------------------------
# 创建模块目录
# ------------------------------
echo "📂 Creating module directory: $MODULE_NAME"

mkdir -p "$MODULE_NAME"
mkdir -p "$MODULE_NAME/src"
mkdir -p "$MODULE_NAME/test"
mkdir -p "$MODULE_NAME/build"

cd "$MODULE_NAME"

# ------------------------------
# 创建 csproj
# ------------------------------
echo "🛠 Creating $PROJECT_TYPE project: $MODULE_NAME"

CS_PROJ="$MODULE_NAME.csproj"
CLASS_NAME="${CUSTOM_MAIN^}"
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
EOF

# ------------------------------
# 添加主代码
# ------------------------------
echo "🛠 Adding default module code"

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
# 添加基础测试
# ------------------------------
echo "🛠 Adding test.cs"

cat > "test/test.cs" <<EOF
using System;
using Xunit;
using $MODULE_NAME;

namespace $MODULE_NAME.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            $CLASS_NAME.Main(Array.Empty<string>());
            Assert.True(true); // 示例测试
        }
    }
}
EOF

echo "✅ Module $MODULE_NAME created successfully."

code .