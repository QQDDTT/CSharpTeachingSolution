using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

namespace MainWeb
{
    /// <summary>
    /// 主 Web 程序入口
    /// 支持静态文件加载、验证码生成与登录验证
    /// </summary>
    public class MainWeb
    {
        // 最大并发用户数（仅限制非静态资源的请求）
        private static readonly int MaxUsers = 1;

        // 信号量用于限制最大并发用户
        // 注意：静态资源请求（CSS、JS、图片等）不受此限制
        private static readonly SemaphoreSlim UserSemaphore = new(MaxUsers, MaxUsers);

        // 活跃用户 Session 管理（线程安全）
        private static readonly ConcurrentDictionary<string, bool> ActiveSessions = new();

        // 有效验证码存储（code -> 创建时间戳）
        private static readonly ConcurrentDictionary<string, long> ValidCodes = new();

        // 脚本常量
        private const string RESTART_WIN = "restart.bat";
        private const string CLOSE_WIN = "close.bat";
        private const string RESTART_LINUX = "restart.sh";
        private const string CLOSE_LINUX = "close.sh";

        // 模块名（供脚本调用）
        private const string MODULE_NAME = "MainWeb";

        public static void Main(string[] args)
        {
            Console.WriteLine("Starting MainWeb server...");
            foreach (var arg in args) Console.WriteLine($"Arg: {arg}");

            // 创建 Web 应用
            var builder = WebApplication.CreateBuilder(args);
            builder.Services.AddDistributedMemoryCache();
            builder.Services.AddSession(options =>
            {
                options.IdleTimeout = TimeSpan.FromMinutes(30); // Session 超时时间
                options.Cookie.HttpOnly = true;
            });

            var app = builder.Build();

            // 启用 Session 中间件
            app.UseSession();

            // 并发访问限制中间件（排除静态资源）
            app.Use(async (context, next) =>
            {
                // 检查是否为静态资源请求
                bool isStaticResource = IsStaticResourceRequest(context.Request.Path);

                string sessionId = context.Session.Id;
                bool isNewUser = !ActiveSessions.ContainsKey(sessionId);

                // 静态资源跳过并发限制，直接处理
                if (isStaticResource)
                {
                    try
                    {
                        await next.Invoke();
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"[Error] {ex.Message}");
                        context.Response.StatusCode = 500;
                        await context.Response.WriteAsync("Internal Server Error");
                    }
                    return;
                }

                // 非静态资源：应用并发控制
                if (isNewUser)
                {
                    if (!UserSemaphore.Wait(0))
                    {
                        context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
                        await context.Response.WriteAsync("Server busy, maximum users reached.");
                        return;
                    }
                    ActiveSessions.TryAdd(sessionId, true);
                }

                try
                {
                    await next.Invoke();
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"[Error] {ex.Message}");
                    context.Response.StatusCode = 500;
                    await context.Response.WriteAsync("Internal Server Error");
                }
                finally
                {
                    if (isNewUser)
                    {
                        ActiveSessions.TryRemove(sessionId, out _);
                        UserSemaphore.Release();
                    }
                }
            });

            // 依赖的服务 / 管理类实例
            var projectManager = new ProjectManager();
            var terminalExecutor = new TerminalExecutor();

            // ---------- 路由：系统验证（GET /system?action=...） ----------
            app.MapGet("/system", (HttpRequest req, HttpResponse resp) =>
            {
                string? action = req.Query["action"];
                resp.ContentType = "application/json; charset=utf-8";

                if (string.IsNullOrEmpty(action))
                    return Results.Json(ResponseData.Error("missing action"));

                if (!CheckScriptExists(action))
                    return Results.Json(ResponseData.Error($"script not found for action: {action}"));

                // 生成验证码（5分钟有效）
                string code = Guid.NewGuid().ToString();
                ValidCodes[code] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

                var data = new Dictionary<string, string> { ["code"] = code };
                return Results.Json(ResponseData.Success($"Verify {action}", data));
            });

            // ---------- 路由：执行脚本（POST /system, form-data 或 application/x-www-form-urlencoded） ----------
            app.MapPost("/system", async (HttpRequest req) =>
            {
                var form = await req.ReadFormAsync();
                string? action = form["action"];
                string? code = form["code"];

                if (string.IsNullOrEmpty(action) || string.IsNullOrEmpty(code))
                    return Results.Json(ResponseData.Error("missing parameters"));

                if (!ValidCodes.TryGetValue(code, out long createTime))
                    return Results.Json(ResponseData.Error("invalid or expired code"));

                // 验证是否超时（5分钟）
                if (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - createTime > 5 * 60_000)
                    return Results.Json(ResponseData.Error("invalid or expired code"));

                string? scriptName = GetScriptName(action);
                if (scriptName == null)
                    return Results.Json(ResponseData.Error("unknown action"));

                // 异步延时 5 秒执行脚本
                _ = Task.Run(async () =>
                {
                    await Task.Delay(5000);
                    ExecuteScript(scriptName);
                });

                return Results.Json(ResponseData.Success("Command scheduled"));
            });

            // 项目接口
            app.MapGet("/project", (HttpRequest req) =>
            {
                string action = req.Query["action"];
                ResponseData result = action switch
                {
                    "projects" => projectManager.ListModules(),
                    "list" => projectManager.ListProjectFiles(req.Query["project"]),
                    "read_file" => projectManager.ReadFile(req.Query["project"], req.Query["path"]),
                    _ => ResponseData.Error($"Unknown GET action: {action}")
                };
                return Results.Json(result);
            });

            app.MapPost("/project", async (HttpRequest req, HttpResponse resp) =>
            {
                string action = req.Query["action"];
                ResponseData result;

                switch (action)
                {
                    case "write_file":
                        {
                            string project = req.Query["project"];
                            string path = req.Query["path"];

                            using var reader = new StreamReader(req.Body, Encoding.UTF8);
                            string content = await reader.ReadToEndAsync();

                            result = projectManager.WriteFile(project, path, content);
                            break;
                        }

                    default:
                        result = ResponseData.Error($"Unknown POST action: {action}");
                        break;
                }

                await result.SendJsonAsync(resp);
            });

            // 执行终端命令
            app.MapGet("/terminal", (HttpRequest req) =>
            {
                string action = req.Query["action"];
                ResponseData result = action switch
                {
                    "start" => terminalExecutor.StartCommand(req.Query["cmd"]),
                    "poll" => terminalExecutor.PollOutput(),
                    _ => ResponseData.Error($"Unknown action: {action}")
                };
                return Results.Json(result);
            });

            // 静态文件加载
            app.MapGet("/{**filepath}", (string? filepath) =>
            {
                if (string.IsNullOrEmpty(filepath))
                    filepath = "home.html";

                string baseDir = AppContext.BaseDirectory;
                string fullPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", "src", filepath));

                return LoadFile(fullPath);
            });


            // 心跳接口
            app.MapGet("/heartbeat", () => Results.Text("OK", "text/plain"));

            // 启动服务
            app.Run(args[1]);
        }

        // ---------------- 文件加载 ----------------
        
        /// <summary>
        /// 判断请求路径是否为静态资源
        /// 静态资源包括：HTML、CSS、JS、图片、字体等文件
        /// </summary>
        private static bool IsStaticResourceRequest(PathString path)
        {
            // 如果路径为空或根路径，不是静态资源请求
            if (!path.HasValue || path.Value == "/")
                return false;

            string pathValue = path.Value.ToLower();

            // 排除 API 路径（这些需要并发控制）
            if (pathValue.StartsWith("/system") || 
                pathValue.StartsWith("/project") || 
                pathValue.StartsWith("/terminal") ||
                pathValue.StartsWith("/heartbeat"))
                return false;

            // 检查文件扩展名
            string extension = Path.GetExtension(pathValue);
            
            // 静态资源文件扩展名列表
            string[] staticExtensions = new[]
            {
                ".html", ".htm",           // HTML 文件
                ".css",                    // CSS 样式
                ".js",                     // JavaScript
                ".json",                   // JSON 数据
                ".png", ".jpg", ".jpeg",   // 图片
                ".gif", ".svg", ".ico",    // 图片
                ".woff", ".woff2",         // 字体
                ".ttf", ".eot",            // 字体
                ".txt", ".xml",            // 文本文件
                ".pdf", ".zip"             // 文档
            };

            return staticExtensions.Contains(extension);
        }

        public static IResult LoadHtml(string filePath) => LoadFile(filePath);

        /// <summary>
        /// 通用静态文件加载器
        /// </summary>
        public static IResult LoadFile(string filePath)
        {
            if (!File.Exists(filePath))
                return Results.NotFound($"File not found: {filePath}");

            string ext = Path.GetExtension(filePath).ToLower();
            string contentType = ext switch
            {
                ".html" => "text/html; charset=utf-8",
                ".css" => "text/css; charset=utf-8",
                ".js" => "application/javascript; charset=utf-8",
                ".json" => "application/json; charset=utf-8",
                ".png" => "image/png",
                ".jpg" or ".jpeg" => "image/jpeg",
                ".gif" => "image/gif",
                ".svg" => "image/svg+xml",
                _ => "application/octet-stream"
            };

            try
            {
                // 对于二进制文件直接返回文件流
                if (contentType.StartsWith("image") || contentType == "application/octet-stream")
                {
                    var bytes = File.ReadAllBytes(filePath);
                    return Results.File(bytes, contentType);
                } 

                string content = File.ReadAllText(filePath);
                return Results.Content(content, contentType);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[LoadFile Error] {ex}");
                return Results.Problem($"Error loading file: {ex.Message}");
            }
        }

        /// <summary>
        /// 根据动作名返回脚本路径（含 scripts 文件夹）
        /// </summary>
        private static string? GetScriptName(string action)
        {
            bool isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
            return action.ToLower() switch
            {
                "restart" => Path.Combine("scripts", isWindows ? RESTART_WIN : RESTART_LINUX),
                "close" => Path.Combine("scripts", isWindows ? CLOSE_WIN : CLOSE_LINUX),
                _ => null
            };
        }

        /// <summary>
        /// 检查脚本文件是否存在
        /// </summary>
        private static bool CheckScriptExists(string action)
        {
            string? scriptPath = GetScriptName(action);
            return scriptPath != null && File.Exists(scriptPath);
        }


        /// <summary>
        /// 执行脚本（异步执行，不阻塞主线程）
        /// </summary>
        private static void ExecuteScript(string scriptName)
        {
            bool isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
            string scriptPath = Path.GetFullPath(scriptName);

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = isWindows ? "cmd.exe" : "/bin/bash",
                    Arguments = isWindows ? $"/c \"{scriptPath}\" {MODULE_NAME}" : $"{scriptPath} {MODULE_NAME}",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                Process.Start(psi);
                Console.WriteLine($"Script executed: {scriptPath}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Execute script failed: {ex.Message}");
            }
        }


    }

    /// <summary>
    /// ResponseData
    /// 用于封装接口响应数据
    /// </summary>
    public class ResponseData
    {
        public int Status { get; set; }
        public string Message { get; set; } = "";
        public Dictionary<string, string> Map { get; set; } = new();

        public ResponseData(int status, string message)
        {
            Status = status;
            Message = message;
            Map = new Dictionary<string, string>();
        }

        public ResponseData(int status, string message, Dictionary<string, string> map)
        {
            Status = status;
            Message = message;
            Map = map ?? new Dictionary<string, string>();
        }

        /// <summary>
        /// 成功响应
        /// </summary>
        public static ResponseData Success(string message, Dictionary<string, string>? map = null)
        {
            return new ResponseData(200, message, map ?? new Dictionary<string, string>());
        }
        /// <summary>
        /// 错误响应
        /// </summary>
        public static ResponseData Error(string message)
        {
            return new ResponseData(500, message, new Dictionary<string, string>());
        }

        /// <summary>
        /// 输出 JSON 到 HttpResponse
        /// </summary>
        public async Task SendJsonAsync(HttpResponse response)
        {
            response.StatusCode = Status;
            response.ContentType = "application/json; charset=utf-8";

            var options = new JsonSerializerOptions
            {
                WriteIndented = false,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };

            await response.WriteAsync(JsonSerializer.Serialize(this, options));
        }

        /// <summary>
        /// 转 JSON 字符串
        /// </summary>
        public string ToJson()
        {
            var options = new JsonSerializerOptions
            {
                WriteIndented = false,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };
            return JsonSerializer.Serialize(this, options);
        }
    }



    // ----------------------------
    // 项目管理逻辑
    // ----------------------------
    public class ProjectManager
    {
        private readonly string ParentDir;
        private readonly ConcurrentDictionary<string, string> Projects;

        public ProjectManager()
        {
            string currentDir = Directory.GetCurrentDirectory();
            ParentDir = Directory.GetParent(currentDir)?.FullName;
            Projects = new ConcurrentDictionary<string, string>(
                Directory.GetDirectories(ParentDir)
                         .Where(d => Path.GetFileName(d).StartsWith("Module.") || Path.GetFileName(d).StartsWith("Web."))
                         .ToDictionary(d => Path.GetFileName(d), d => d)
            );
        }

        // ========== 文件功能 ==========
        public ResponseData ReadFile(string project, string relativePath)
        {
            try
            {
                string filePath = Path.Combine(Projects[project], relativePath);
                return ResponseData.Success("Read file success", new Dictionary<string, string>
                {
                    ["file"] = relativePath,
                    ["content"] = File.ReadAllText(filePath)
                });
            }
            catch (Exception e)
            {
                return ResponseData.Error(e.Message);
            }
        }
        public ResponseData WriteFile(string project, string relativePath, String content)
        {
            try
            {
                if (!Projects.TryGetValue(project, out string root))
                    return ResponseData.Error($"Project not found: {project}");

                string filePath = Path.Combine(Projects[project], relativePath);

                File.WriteAllText(filePath, content, Encoding.UTF8);

                return ResponseData.Success($"Write file success: {relativePath}", new Dictionary<string, string>());
            }
            catch (Exception e)
            {
                return ResponseData.Error($"Write file failed: {e.Message}");
            }
        }

        // ========== 项目管理 ==========
        public ResponseData ListModules() => ResponseData.Success("Sub projects", Projects.ToDictionary(kv => kv.Key, kv => kv.Value));

        public ResponseData ListProjectFiles(string project)
        {
            try
            {
                string root = Projects[project];
                var files = Directory.GetFileSystemEntries(root, "*", SearchOption.AllDirectories)
                                     .Where(p => !p.Contains("build") && !p.Contains("obj"))
                                     .ToDictionary(
                                        p => Path.GetRelativePath(root, p),
                                        p => Directory.Exists(p) ? "Dir" : "File"
                                     );
                return ResponseData.Success("List file success", files);
            }
            catch (Exception e)
            {
                return ResponseData.Error(e.Message);
            }
        }

    }

    /// <summary>
    /// TerminalExecutor
    /// 管理命令队列和输出队列，同时区分 stdout 和 stderr
    /// </summary>
    public class TerminalExecutor
    {
        // 输出队列
        private readonly ConcurrentQueue<Dictionary<string, string>> outputQueue = new();
        // 是否正在执行命令
        private volatile bool running = false;
        // 命令超时时间（毫秒）
        private readonly int commandTimeoutMillis = 30_000;

        // 根目录（项目目录的上一级）
        public string RootDir { get; }

        // 当前执行目录，相对于 RootDir 的路径
        public string CurrentDir { get; private set; } = ".";


        /// <summary>
        /// 构造函数，初始化 RootDir
        /// </summary>
        public TerminalExecutor()
        {
            // 获取项目目录的上一级
            RootDir = Directory.GetParent(Directory.GetCurrentDirectory())?.FullName
                    ?? Directory.GetCurrentDirectory();
        }

        /// <summary>
        /// 启动命令执行，将 stdout 和 stderr 输出存入队列
        /// </summary>
        public ResponseData StartCommand(string command)
        {
            if (running)
            {
                return ResponseData.Error("Command is running");
            }

            running = true;
            outputQueue.Clear();

            // 处理 cd 命令
            if (command.StartsWith("cd "))
            {
                string targetDir = command.Substring(3).Trim();
                string newDir = Path.GetFullPath(Path.Combine(RootDir, CurrentDir, targetDir));

                if (Directory.Exists(newDir))
                {
                    CurrentDir = Path.GetRelativePath(RootDir, newDir);
                    running = false;
                    return ResponseData.Success("Directory changed", new Dictionary<string, string> { ["path"] = CurrentDir });
                }
                else
                {
                    running = false;
                    return ResponseData.Error("Directory does not exist: " + targetDir);
                }
            }
            
            // 判断操作系统类型
            string shell;
            string shellArgs;

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                shell = "cmd.exe";
                shellArgs = "/C " + command;
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux) || RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                shell = "/bin/bash";
                shellArgs = "-c \"" + command + "\"";
            }
            else
            {
                running = false;
                return ResponseData.Error("Unsupported operating system");
            }

            Task.Run(() =>
            {
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = shell,
                        Arguments = shellArgs,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WorkingDirectory = Path.Combine(RootDir, CurrentDir)
                    };

                    using var process = new Process { StartInfo = psi };
                    process.Start();

                    // 异步读取 stdout
                    var stdoutTask = Task.Run(() =>
                    {
                        string line;
                        while ((line = process.StandardOutput.ReadLine()) != null)
                        {
                            outputQueue.Enqueue(new Dictionary<string, string>
                            {
                                ["type"] = "out",
                                ["text"] = line
                            });
                        }
                    });

                    // 异步读取 stderr
                    var stderrTask = Task.Run(() =>
                    {
                        string line;
                        while ((line = process.StandardError.ReadLine()) != null)
                        {
                            outputQueue.Enqueue(new Dictionary<string, string>
                            {
                                ["type"] = "err",
                                ["text"] = line
                            });
                        }
                    });

                    // 等待进程结束或超时
                    bool finished = process.WaitForExit(commandTimeoutMillis);
                    if (!finished)
                    {
                        process.Kill(true);
                        outputQueue.Enqueue(new Dictionary<string, string>
                        {
                            ["type"] = "err",
                            ["text"] = $"Command timed out after {commandTimeoutMillis / 1000} seconds"
                        });
                    }

                    Task.WaitAll(stdoutTask, stderrTask);
                }
                catch (Exception ex)
                {
                    outputQueue.Enqueue(new Dictionary<string, string>
                    {
                        ["type"] = "err",
                        ["text"] = "Run command failed: " + ex.Message
                    });
                }
                finally
                {
                    running = false;
                }
            });

            return ResponseData.Success("Command started", new Dictionary<string, string> { ["running"] = "1" });
        }

        /// <summary>
        /// 获取队列输出，并返回 ResponseData
        /// </summary>
        public ResponseData PollOutput()
        {
            var outSb = new StringBuilder();
            var errSb = new StringBuilder();
            var map = new Dictionary<string, string>();

            while (outputQueue.TryDequeue(out var entry))
            {
                string type = entry["type"];
                string text = entry["text"];
                if (type == "err")
                    errSb.AppendLine(text);
                else
                    outSb.AppendLine(text);
            }

            map["out"] = outSb.ToString();
            map["err"] = errSb.ToString();
            map["running"] = running ? "1" : "0";
            map["path"] = CurrentDir;

            return ResponseData.Success("Get output", map);
        }

    }
}