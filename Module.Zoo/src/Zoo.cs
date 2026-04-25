using System;
using System.Collections;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices.Marshalling;
namespace Module.Zoo
{
    public class Zoo
    {
        private readonly static Dictionary<string, Dog> Dogs = new Dictionary<string, Dog>();
        public static void Main(string[] args)
        {
            Dogs["father"] = new Dog("father", Gender.Male, Color.White);
            print<Dog>(Dogs);
        }

        private static void print<T>(Dictionary<string, T> animals) where T : IAnimal<T>
        {
            foreach (T animal in animals.Values)
            {
                Console.WriteLine("-------");
                print<T>(animal);
            }
        }

        private static void print<T>(T animal) where T : IAnimal<T>
        {
            Console.WriteLine(animal.Message());
        }
    }
}
