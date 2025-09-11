using System;
namespace Module.BasicGrammar
{
    public class BasicGrammar
    {

        public static void Main(string[] args)
        {
            int a = 3;
            Console.WriteLine(++a);
            Console.WriteLine(a);

            int b = 3;
            Console.WriteLine(b++);
            Console.WriteLine(b);
        }

        private static int run()
        {
            return 0;
        }
    }
}
