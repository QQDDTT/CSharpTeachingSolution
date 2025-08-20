using System;
using Xunit;
using Module.Hello;

namespace Module.Hello.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            Hello.Main(Array.Empty<string>());
            Assert.True(true); // 示例测试
        }
    }
}
