using System;
using Xunit;
using System.Diagnostics;
using MainWeb;

namespace MainWeb.Tests
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
            var result = MainWeb.LoadHtml(htmlPath);
            Console.WriteLine(result);
            sw.Stop();
            Assert.True(true); // 示例测试
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
