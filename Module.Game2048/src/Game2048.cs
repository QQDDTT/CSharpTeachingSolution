using System;
using System.Collections.Specialized;
using System.Dynamic;
using System.Runtime.CompilerServices;
using System.Text.Json;
namespace Module.Game2048
{
    public class Game2048
    {
        /// <summary>
        /// 控制台程序入口点。
        /// 初始化一个 2048 游戏表格，并允许玩家通过键盘方向键进行操作。
        /// 游戏会在无法继续或达到目标值时结束。
        /// </summary>
        public static void Main(string[] args)
        {
            Table2048 table = new Table2048();
            Console.WriteLine("START");

            // 初始化游戏
            table.Start();
            Console.WriteLine(table.ToString());
            Console.WriteLine(table.ToString());

            // 游戏循环，直到 Next() 返回 false
            do
            {
                Console.WriteLine("按方向键继续...");
                ConsoleKeyInfo keyInfo = Console.ReadKey(true);

                // 根据输入方向执行移动
                switch (keyInfo.Key)
                {
                    case ConsoleKey.LeftArrow:
                        table.Left();
                        break;
                    case ConsoleKey.RightArrow:
                        table.Right();
                        break;
                    case ConsoleKey.UpArrow:
                        table.Up();
                        break;
                    case ConsoleKey.DownArrow:
                        table.Down();
                        break;
                    default:
                        Console.WriteLine("请输入方向键");
                        break;
                }

                // 打印当前棋盘
                Console.WriteLine(table.ToString());
            }
            while (table.Next()); // 判断是否还能继续游戏
            Console.WriteLine("FINISH");
        }
    }

    public class Table2048
    {
        private Random random = new Random();
        private static readonly int MAX_VAL = 2048; // 胜利条件的最大值
        private uint[] form;                        // 存储棋盘数据的数组
        private uint rowCount;                      // 行数
        private uint colCount;                      // 列数

        /// <summary>
        /// 默认构造函数，初始化为 4x4 棋盘。
        /// </summary>
        public Table2048() : this(4, 4) { }

        /// <summary>
        /// 带参数构造函数，创建指定行列数的棋盘。
        /// 限制：行列数必须在 3~9 之间。
        /// </summary>
        public Table2048(uint rowCount, uint colCount)
        {
            if (rowCount < 3 || colCount < 3) throw new ArgumentException("Row Colume count must be more than 3");
            if (rowCount > 9 || colCount > 9) throw new ArgumentException("Row Colume count must be less than 10");
            this.rowCount = rowCount;
            this.colCount = colCount;
            this.form = new uint[rowCount * colCount];
        }

        /// <summary>
        /// 初始化棋盘。
        /// 随机选取 3 个位置放置初始数字（1、2 或 4），其余位置为 0。
        /// </summary>
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

        /// <summary>
        /// 随机生成一个新的数字。
        /// 60% 概率为 1，30% 概率为 2，10% 概率为 4。
        /// </summary>
        private uint RandomVal()
        {
            int probability = random.Next(1, 100);
            if (probability < 60) return 1;
            if (probability < 90) return 2;
            return 4;
        }

        /// <summary> 获取某位置左边位置索引（若越界则抛异常）。 </summary>
        private int GetLeftPosition(int index)
        {
            if (index % colCount == 0) throw new Exception();
            return index - 1;
        }

        /// <summary> 获取某位置右边位置索引（若越界则抛异常）。 </summary>
        private int GetRightPosition(int index)
        {
            if (index % colCount == colCount - 1) throw new Exception();
            return index + 1;
        }

        /// <summary> 获取某位置上方位置索引（若越界则抛异常）。 </summary>
        private int GetUpPosition(int index)
        {
            if (index < colCount) throw new Exception();
            return index - (int)colCount;
        }

        /// <summary> 获取某位置下方位置索引（若越界则抛异常）。 </summary>
        private int GetDownPosition(int index)
        {
            if (index >= (rowCount - 1) * colCount) throw new Exception();
            return index + (int)colCount;
        }

        /// <summary>
        /// 游戏下一步。
        /// 1. 判断是否有空格（或是否已经达到最大值）。
        /// 2. 如果有空格，则随机生成一个新数字放置。
        /// 返回 true 表示游戏可以继续，false 表示结束。
        /// </summary>
        public bool Next()
        {
            bool result = false;
            HashSet<int> spaceList = new HashSet<int>();
            for (int i = 0; i < form.Length; i++)
            {
                if (form[i] == 0) result = spaceList.Add(i);  // 有空格,继续
                if (form[i] == MAX_VAL) result = false;       // 达到 2048，结束
            }
            if (result) form[spaceList.ToArray()[random.Next(0, spaceList.Count)]] = RandomVal();
            return result;
        }

        /// <summary> 向左移动并合并。 </summary>
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

        /// <summary> 向右移动并合并。 </summary>
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

        /// <summary> 向上移动并合并。 </summary>
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

        /// <summary> 向下移动并合并。 </summary>
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
        /// 压缩并合并一行/一列。
        /// 规则：
        /// - 跳过空格。
        /// - 相邻相同数字则合并（左或上优先）。
        /// - 数字移动到最前端，保持紧凑。
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
        /// 打印棋盘的文本表示（ASCII 表格）。
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
        /// 将棋盘状态转换为 JSON 字符串。
        /// 包含：行数、列数、棋盘数据。
        /// </summary>
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
