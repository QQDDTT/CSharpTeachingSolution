using System;
using System.Collections;
using System.Collections.Specialized;
namespace Module.Math
{
    public class Math
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("----Start----");
            int max = 10000;
            int[] result = PrimeNumber(max);
            for (int i = 0; i < result.Length; i++)
            {
                Console.WriteLine(result[i]);
            }
            Console.WriteLine("----End----");

        }

        private static int[] PrimeNumber(int max)
        {
            int min = 2;
            ArrayList result = new ArrayList();
            result.Add(2);
            for (int i = min; i <= max; i++)
            {
                bool isPrime = true;
                for (int j = min; j < i; j++)
                {
                    if (i % j == 0)
                    {
                        isPrime = false;
                        break;
                    }
                }
                if (isPrime)
                {
                    result.Add(i);
                }
            }
            return (int[])result.ToArray(typeof(int));
        }
    }
}
