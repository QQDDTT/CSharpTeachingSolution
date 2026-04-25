using System;
using Xunit;
using System.Diagnostics;
using Module.String;

namespace Module.String.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            var sw = Stopwatch.StartNew();
            String.Main(Array.Empty<string>());
            sw.Stop();
            Assert.True(true); // 示例测试
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
