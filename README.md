## 目录结构

```bash
MyTeachingSolution/
├── MyTeachingSolution.sln
├── MainApp/
│   ├── src/
│   │   └── Program.cs
│   ├── build/
│   └── MainApp.csproj
├── Module.Hello/
│   ├── src/
│   │   └── Hello.cs
│   ├── test/
│   │   └── test.cs      ← 子项目独立测试入口
│   ├── build/
│   └── Module.Hello.csproj
├── Module.Math/
│   ├── src/
│   │   └── Math.cs
│   ├── test/
│   │   └── test.cs
│   ├── build/
│   └── Module.Math.csproj
└── README.md
```
 
## .csproj 文件结构

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>            <!-- Exe 表示可执行程序 -->
    <TargetFramework>net8.0</TargetFramework> <!-- 使用 .NET 8 -->
    <Nullable>enable</Nullable>             <!-- 启用空值类型支持 -->
    <ImplicitUsings>enable</ImplicitUsings> <!-- 自动引用常用命名空间 -->
  </PropertyGroup>

</Project>
```


## 配置说明

### <Project Sdk="...">

### 指定项目使用的 SDK：

- 控制台 / 类库：Microsoft.NET.Sdk
- Web 应用：Microsoft.NET.Sdk.Web
- Razor 类库：Microsoft.NET.Sdk.Razor

### <PropertyGroup> 内的常见配置

| 标签                  | 说明                                            |
| ------------------- | --------------------------------------------- |
| `<OutputType>`      | `Exe`（应用）或 `Library`（类库）                      |
| `<TargetFramework>` | 目标框架，例如：`net8.0`, `net7.0`, `net6.0`, `net48` |
| `<Nullable>`        | `enable` 启用可空类型检查（推荐）                         |
| `<LangVersion>`     | 指定 C# 语言版本，例如 `11`, `latest`                  |
| `<AssemblyName>`    | 输出程序集名称（默认是项目文件名）                             |
| `<RootNamespace>`   | 根命名空间（可选）                                     |


### 常用命令

- 创建项目

```bash
# 创建一个控制台项目
dotnet new console -n <项目名> -o <项目路径>

# 创建一个类库项目
dotnet new classlib -n <项目名> -o <项目路径>

# 创建一个 Web 项目
dotnet new web -n <项目名> -o <项目路径>
```

- 编译项目

```bash
dotnet build <项目路径> -c [Debug | Release] -o <输出目录>
```

- 运行项目

```bash
dotnet run --project <项目路径> -c [Debug | Release]
```

- 清理项目

```bash
dotnet clean <项目路径>
```

- 发布项目

```bash
dotnet publish <项目路径> -c [Debug | Release] -o <输出目录>
```

- 测试项目

```bash
dotnet test <项目路径> -c [Debug | Release]
```

### 模块创建脚本

- Linux

```bash
chmod +x create_module.sh
./create_module.sh <module_name>
```

- Windows

```powershell
.\create_module.ps1 <module_name>
```

- 如果权限不够

```poweshell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

- Mac

```bash
chmod +x create_module.sh
./create_module.sh <module_name>
```