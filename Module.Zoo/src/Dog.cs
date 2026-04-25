using System.Drawing;
using System.Runtime.CompilerServices;

namespace Module.Zoo
{
    public class Dog : Animal<Dog>, IAnimal<Dog>
    {
        public Dog(string Name, Gender Gender, Color Color) : base(Name, Gender, Color) { }
        public static Dog operator +(Dog a, Dog b)
        {
            if (a.Gender != b.Gender)
            {
                Dog puppy = new Dog("puppy",
                        random.Next(0, 1) < 0.5 ? Gender.Male : Gender.Female,
                        random.Next(0, 1) < 0.5 ? a.Color : b.Color);
                puppy.Father = a.Gender == Gender.Male ? a : b;
                puppy.Mother = a.Gender == Gender.Female ? a : b;
                return puppy;
            }
            throw new ApplicationException("Gender Error!");
        }

        public string Message()
        {
            return $"name: {this.Name}";
        }
    }
}