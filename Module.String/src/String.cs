using System;
namespace Module.String
{
    public class String
    {
        public static void Main(string[] args)
        {
            string a = "a";
            string b = "a";
            Console.WriteLine(a == b);
            string c = new string("a");
            Console.WriteLine(a == c);
            Console.WriteLine(b == c);
        }
    }
}
