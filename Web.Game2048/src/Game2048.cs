using System;
using System.Collections.Specialized;
using System.Dynamic;
using System.Runtime.CompilerServices;
using System.IO;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting;
namespace Web.Game2048
{
    public class Game2048
    {
        /// <summary>
        /// 程序入口点
        /// 构建 ASP.NET Core Web 应用，并映射 2048 游戏相关的路由
        /// </summary>
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            var app = builder.Build();

            // HTML 文件路径 (相对项目目录)
            string baseDir = AppContext.BaseDirectory;
            string relativePath = "src/home.html";
            string htmlPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", relativePath));
            var game = new Table2048();

            // 首页：初始化棋盘并返回 HTML 页面
            app.MapGet("/", (HttpRequest request) =>
            {
                string? row = request.Query["row"];
                string? col = request.Query["col"];
                uint rowNum = ParseUint(row, 4);
                uint colNum = ParseUint(col, 4);
                game = new Table2048(rowNum, colNum);
                game.Start();
                Console.WriteLine(game.ToString());
                return LoadHtml(htmlPath);
            });

            // 返回游戏当前状态（JSON）
            app.MapGet("/state", () => game.ToJsonObject());

            // 重启游戏（POST），并重新生成棋盘
            app.MapPost("/restart", (HttpRequest request) =>
            {
                string? row = request.Query["row"];
                string? col = request.Query["col"];
                uint rowNum = ParseUint(row, 4);
                uint colNum = ParseUint(col, 4);
                game = new Table2048(rowNum, colNum);
                game.Start();
                Console.WriteLine(game.ToString());
                return Results.Ok(game.ToJsonObject());
            });

            // 执行一次移动（left/right/up/down），并生成新数字
            app.MapPost("/move/{dir}", (string dir) =>
            {
                switch (dir.ToLower())
                {
                    case "left": game.Left(); break;
                    case "right": game.Right(); break;
                    case "up": game.Up(); break;
                    case "down": game.Down(); break;
                    default: return Results.BadRequest("Invalid direction, use left/right/up/down");
                }
                game.Next();
                Console.WriteLine(game.ToString());
                return Results.Ok(game.ToJsonObject());
            });
            app.Run();
        }

        /// <summary>
        /// 读取 HTML 文件并返回 HTTP 响应
        /// </summary>
        public static IResult LoadHtml(string filePath)
        {
            if (!File.Exists(filePath))
            {
                return Results.NotFound($"HTML file not found: {filePath}");
            }

            string htmlContent = File.ReadAllText(filePath);
            return Results.Content(htmlContent, "text/html");
        }

        /// <summary>
        /// 尝试将字符串解析为 uint，如果失败则返回默认值
        /// </summary>
        private static uint ParseUint(string? str, uint def)
        {
            if (string.IsNullOrEmpty(str)) return def;
            try
            {
                return uint.Parse(str);
            }
            catch
            {
                return def;
            }
        }
    }

    public class Table2048
    {
        private Random random = new Random();
        private static readonly int MAX_VAL = 2048; // 胜利目标值
        private uint[] form;     // 棋盘（行优先存储的一维数组）
        private uint rowCount;   // 行数
        private uint colCount;   // 列数
        private string status;   // 游戏状态（Wait / Over / Building）

        /// <summary>
        /// 默认构造函数（4x4 棋盘）
        /// </summary>
        public Table2048() : this(4, 4) { }


        /// <summary>
        /// 指定行列数的构造函数
        /// </summary>
        public Table2048(uint rowCount, uint colCount)
        {
            if (rowCount < 3 || colCount < 3) throw new ArgumentException("Row Colume count must be more than 3");
            if (rowCount > 9 || colCount > 9) throw new ArgumentException("Row Colume count must be less than 10");
            this.rowCount = rowCount;
            this.colCount = colCount;
            this.status = "Building";
            this.form = new uint[rowCount * colCount];
        }

        /// <summary>
        /// 初始化游戏，在棋盘上随机生成 3 个数字
        /// </summary>
        public void Start()
        {
            this.form = new uint[rowCount * colCount];
            HashSet<int> positionList = new HashSet<int>();
            while (positionList.Count < 3)
            {
                int position = random.Next(0, form.Length);
                positionList.Add(position);
            }
            for (int i = 0; i < form.Length; i++)
            {
                if (positionList.Contains(i))
                {
                    form[i] = RandomVal();
                }
                else
                {
                    form[i] = 0;
                }
            }
        }

        /// <summary>
        /// 随机生成一个初始值 (60% 概率=1, 30%=2, 10%=4)
        /// </summary>
        private uint RandomVal()
        {
            int probability = random.Next(1, 100);
            if (probability < 60) return 1;
            if (probability < 90) return 2;
            return 4;
        }

        // ================== 工具函数：获取某方向上的相邻格位置 ==================
        private int GetLeftPosition(int index)
        {
            if (index % colCount == 0) throw new Exception();
            return index - 1;
        }
        private int GetRightPosition(int index)
        {
            if (index % colCount == colCount - 1) throw new Exception();
            return index + 1;
        }
        private int GetUpPosition(int index)
        {
            if (index < colCount) throw new Exception();
            return index - (int)colCount;
        }
        private int GetDownPosition(int index)
        {
            if (index >= (rowCount - 1) * colCount) throw new Exception();
            return index + (int)colCount;
        }

        /// <summary>
        /// 执行移动后，生成新数字并检测游戏状态
        /// </summary>
        public void Next()
        {
            status = "Over"; // 默认设为结束
            HashSet<int> spaceList = new HashSet<int>();
            for (int i = 0; i < form.Length; i++)
            {
                if (form[i] == 0)
                {
                    spaceList.Add(i);
                    status = "Wait"; // 仍有空格，游戏继续
                }
                if (form[i] == MAX_VAL) status = "Over"; // 出现 2048，游戏胜利
            }
            // 如果仍有空格，随机生成一个新数字
            if (status == "Wait") form[spaceList.ToArray()[random.Next(0, spaceList.Count)]] = RandomVal();
        }


        /// <summary>
        /// 向左移动并合并
        /// </summary>
        public void Left()
        {
            for (int row = 0; row < rowCount; row++)
            {
                int[] positions = new int[colCount];
                for (int col = 0; col < colCount; col++)
                {
                    positions[col] = row * (int)colCount + col;
                }
                CompressLine(positions);
            }
        }

        /// <summary>
        /// 向右移动并合并
        /// </summary>
        public void Right()
        {
            for (int row = 0; row < rowCount; row++)
            {
                int[] positions = new int[colCount];
                for (int col = 0; col < colCount; col++)
                {
                    positions[col] = row * (int)colCount + ((int)colCount - 1 - col);
                }
                CompressLine(positions);
            }
        }

        /// <summary>
        /// 向上移动并合并
        /// </summary>
        public void Up()
        {
            for (int col = 0; col < colCount; col++)
            {
                int[] positions = new int[rowCount];
                for (int row = 0; row < rowCount; row++)
                {
                    positions[row] = row * (int)colCount + col;
                }
                CompressLine(positions);
            }
        }

        /// <summary>
        /// 向下移动并合并
        /// </summary>
        public void Down()
        {
            for (int col = 0; col < colCount; col++)
            {
                int[] positions = new int[rowCount];
                for (int row = 0; row < rowCount; row++)
                {
                    positions[row] = ((int)rowCount - 1 - row) * (int)colCount + col;
                }
                CompressLine(positions);
            }
        }

        /// <summary>
        /// 压缩并合并一行/列（移动逻辑的核心）
        /// </summary>
        private void CompressLine(int[] positions)
        {
            int target = 0;
            for (int i = 0; i < positions.Length; i++)
            {
                int pos = positions[i];
                if (form[pos] == 0) continue;

                if (target > 0 && form[positions[target - 1]] == form[pos])
                {
                    // 相邻且相等 → 合并
                    form[positions[target - 1]] *= 2;
                    form[pos] = 0;
                }
                else
                {
                    // 向前压缩
                    if (target != i)
                    {
                        form[positions[target]] = form[pos];
                        if (target != i) form[pos] = 0;
                    }
                    target++;
                }
            }
        }

        /// <summary>
        /// 控制台打印棋盘
        /// </summary>
        public override string ToString()
        {
            var sb = new System.Text.StringBuilder();

            int cellWidth = 4; // 每格宽度固定为4
            string line = "+" + string.Concat(Enumerable.Repeat(new string('-', cellWidth) + "+", (int)colCount));

            for (int row = 0; row < rowCount; row++)
            {
                sb.AppendLine(line); // 行头线

                for (int col = 0; col < colCount; col++)
                {
                    sb.Append("|");
                    uint val = form[row * colCount + col];
                    string str = val == 0 ? new string(' ', cellWidth) : val.ToString().PadLeft(cellWidth);
                    sb.Append(str);
                }
                sb.AppendLine("|"); // 行尾
            }

            sb.AppendLine(line); // 底线
            return sb.ToString();
        }

        /// <summary>
        /// 将棋盘转为 JSON 对象，用于前端交互
        /// </summary>
        public object ToJsonObject()
        {
            return new
            {
                RowCount = rowCount,
                ColCount = colCount,
                Status = status,
                Form = form
            };
        }
    }
}
