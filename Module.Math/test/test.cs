using System;
using Xunit;
using System.Diagnostics;
using Module.Math;

namespace Module.Math.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            var sw = Stopwatch.StartNew();
            Math.Main(Array.Empty<string>());
            sw.Stop();
            Assert.True(true); // 示例测试
            Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
        }
    }
}
