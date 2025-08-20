using System;
using System.IO;
using System.Linq;
using System.Reflection;

class Program
{
    static void Main()
    {
        Console.WriteLine("=== MainApp started ===");

        // 提示用户输入模块名
        Console.Write("Enter module name to run (e.g., Module.Hello): ");
        string moduleName = Console.ReadLine()?.Trim()??"Module.Hello";

        if (string.IsNullOrEmpty(moduleName))
        {
            Console.WriteLine("⚠️ Module name is empty.");
            return;
        }

        string mainAppDir = AppContext.BaseDirectory;

        string moduleDir = mainAppDir.Replace("MainApp", moduleName);

        // 构建目标 DLL 路径：假设模块在子项目 build 文件夹里
        string dllPath = Path.Combine(moduleDir, $"{moduleName}.dll");

        if (!File.Exists(dllPath))
        {
            Console.WriteLine($"❌ Module DLL not found: {dllPath}");
            return;
        }

        try
        {
            Console.WriteLine($"🔍 Loading module: {dllPath}");
            var asm = Assembly.LoadFrom(dllPath);

            // 找到第一个包含 Run() 方法的类并执行
            var type = asm.GetTypes().FirstOrDefault(t => t.GetMethod("Main") != null);
            if (type != null)
            {
                var method = type.GetMethod("Main")!;
                Console.WriteLine($"💡 Invoking {type.FullName}.Main()");
                Console.WriteLine("=== Module started ===");
                method.Invoke(Activator.CreateInstance(type), new object[] { Array.Empty<string>() });
                Console.WriteLine("=== Module stopped ===");
            }
            else
            {
                Console.WriteLine("⚠️ No class with Main() method found in DLL.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Failed to load module: {ex.Message}");
        }
    }
}
