using System;
namespace Module.GuessWord
{
    public class GuessWord
    {
        public static void Main(string[] args)
        {
            // 词库
            string[] words = { "apple", "banana", "orange", "grape", "cherry", "mango", "peach" };
            Random rand = new Random();
            string answer = words[rand.Next(words.Length)];

            int maxAttempts = 5;
            int attempt = 0;

            // 显示单词长度和部分提示字母
            char[] hint = new char[answer.Length];
            for (int i = 0; i < answer.Length; i++)
            {
                hint[i] = '_';
            }

            // 随机显示 2 个字母
            for (int i = 0; i < 2; i++)
            {
                int index = rand.Next(answer.Length);
                hint[index] = answer[index];
            }

            Console.WriteLine("🎯 猜单词游戏开始！");
            Console.WriteLine($"提示：单词长度是 {answer.Length} 个字母");
            Console.WriteLine($"部分提示：{new string(hint)}");
            Console.WriteLine($"你有 {maxAttempts} 次机会。");

            // 游戏循环
            while (attempt < maxAttempts)
            {
                Console.Write($"\n第 {attempt + 1} 次尝试，请输入你的猜测：");
                string guess = Console.ReadLine()?.ToLower() ?? "";

                if (guess.Length != answer.Length)
                {
                    Console.WriteLine("❗ 长度不匹配，请输入相同长度的单词！");
                    continue;
                }

                attempt++;

                if (guess == answer)
                {
                    Console.WriteLine("🎉 恭喜！你猜对了！");
                    return;
                }

                // 统计猜对的字母数（按位置）
                int correctCount = 0;
                for (int i = 0; i < answer.Length; i++)
                {
                    if (guess[i] == answer[i])
                        correctCount++;
                }

                Console.WriteLine($"🔎 猜对了 {correctCount} 个字母（位置正确）。");

                // 最后一次机会
                if (attempt == maxAttempts)
                {
                    Console.WriteLine("\n💀 游戏结束！");
                    Console.WriteLine($"正确答案是：{answer}");
                }
            }
        }
    }
}
