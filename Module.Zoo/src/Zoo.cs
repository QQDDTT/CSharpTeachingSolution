using System;
using System.Collections;
namespace Module.Zoo
{
    public class Zoo
    {
        private readonly static Dictionary<string, Dog> Dogs = new Dictionary<string, Dog>();
        public static void Main(string[] args)
        {
            Dogs["father"] = new Dog();
        }
    }
}
