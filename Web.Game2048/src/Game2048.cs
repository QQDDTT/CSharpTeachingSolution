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
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            var app = builder.Build();
            string baseDir = AppContext.BaseDirectory;
            string relativePath = "src/home.html";
            string htmlPath = Path.GetFullPath(Path.Combine(baseDir, "..", "..", relativePath));
            var game = new Table2048(4, 4);
            app.MapGet("/", () => LoadHtml(htmlPath));
            app.MapGet("/state", () => game.ToJson());
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
                return Results.Ok(game.ToJson());
            });
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
    public class Table2048
    {
        private Random random = new Random();
        private static readonly int MAX_VAL = 2048;
        private uint[] form;
        private uint rowCount;
        private uint colCount;

        public Table2048() : this(4, 4) { }
        public Table2048(uint rowCount, uint colCount)
        {
            if (rowCount < 3 || colCount < 3) throw new ArgumentException("Row Colume count must be more than 3");
            if (rowCount > 9 || colCount > 9) throw new ArgumentException("Row Colume count must be less than 10");
            this.rowCount = rowCount;
            this.colCount = colCount;
            this.form = new uint[rowCount * colCount];
        }
        public void Start()
        {
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

        private uint RandomVal()
        {
            int probability = random.Next(1, 100);
            if (probability < 60) return 1;
            if (probability < 90) return 2;
            return 4;
        }

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

        public bool Next()
        {
            bool result = false;
            HashSet<int> spaceList = new HashSet<int>();
            for (int i = 0; i < form.Length; i++)
            {
                if (form[i] == 0) result = spaceList.Add(i);
                if (form[i] == MAX_VAL) result = false;
            }
            if (result) form[spaceList.ToArray()[random.Next(0, spaceList.Count)]] = RandomVal();
            return result;
        }

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

        private void CompressLine(int[] positions)
        {
            int target = 0;
            for (int i = 0; i < positions.Length; i++)
            {
                int pos = positions[i];
                if (form[pos] == 0) continue;

                if (target > 0 && form[positions[target - 1]] == form[pos])
                {
                    // 合并
                    form[positions[target - 1]] *= 2;
                    form[pos] = 0;
                }
                else
                {
                    if (target != i)
                    {
                        form[positions[target]] = form[pos];
                        if (target != i) form[pos] = 0;
                    }
                    target++;
                }
            }
        }

        public override string ToString()
        {
            var sb = new System.Text.StringBuilder();

            for (int row = 0; row < rowCount; row++)
            {
                sb.AppendLine("+----+----+----+----+"); // 表头线
                for (int col = 0; col < colCount; col++)
                {
                    sb.Append("|");
                    uint val = form[row * colCount + col];
                    if (val == 0)
                        sb.Append("    "); // 空格填充
                    else
                        sb.Append(val.ToString().PadLeft(4)); // 数字右对齐
                }
                sb.AppendLine("|"); // 每行结束
            }
            sb.AppendLine("+----+----+----+----+"); // 底线

            return sb.ToString();
        }

        public string ToJson()
        {
            var data = new
            {
                RowCount = rowCount,
                ColCount = colCount,
                Form = form
            };

            return JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
        }


    }
}
