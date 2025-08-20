using System;
using Xunit;
using Module.Math;

namespace Module.Math.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            Math.Main(Array.Empty<string>());
            Assert.True(true); // 示例测试
        }
    }
}
