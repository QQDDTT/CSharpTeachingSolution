using System;
using Xunit;
using Module.MyMath;

namespace Module.MyMath.Tests
{
    public class TestModule
    {
        [Fact]
        public void RunTest()
        {
            MyMath.Main(Array.Empty<string>());
            Assert.True(true); // 示例测试
        }
    }
}
