using System;
namespace Module.IO
{
    public class IO
    {
        public static void Main(string[] args)
        {
            for (char c = 'a'; c <= 'z'; c++)
            {
                Console.Write(c switch
                {
                    'g' or 'n' or 't' or 'z'=> c.ToString() + '\n',
                    'q' or 'w' => c.ToString() + ' ',
                    _ => c.ToString()
                });
            }
        }
    }
}
