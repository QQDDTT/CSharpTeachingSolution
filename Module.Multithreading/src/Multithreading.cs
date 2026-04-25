using System;
using System.Threading;
namespace Module.Multithreading
{
    public class Multithreading
    {
        static void ChildThreadMethod()
        {
            for (int i = 0; i < 5; i++)
            Console.WriteLine("Hello from Child Thread!");
        }
        public static void Main(string[] args)
        {
            Thread childThread = new Thread(ChildThreadMethod);
            childThread.Start();
            for (int i = 0; i < 5; i++)
            Console.WriteLine("Hello from Main Thread!");
        }
    }
}
