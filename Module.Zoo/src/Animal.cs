using System;
using System.Drawing;
using System.Runtime.CompilerServices;

namespace Module.Zoo
{
    public interface IAnimal<Self> where Self : IAnimal<Self>
    {
        // ✅ 只有接口能定义静态抽象运算符
        static abstract Self operator +(Self a, Self b);
        string Message();
    }

    public abstract class Animal<Self> where Self : Animal<Self>
    {
        protected static readonly Random random = new Random();
        public static readonly Food[] Foods = { };
        public string Name { get; set; } = "";
        public uint Age { get; set; } = 0;
        public Gender Gender { get; set; } = Gender.Male;
        public Color Color { get; set; } = Color.White;
        public Self? Father;
        public Self? Mother;
        public Animal(string Name, Gender Gender, Color Color)
        {
            this.Name = Name;
            this.Gender = Gender;
            this.Color = Color;
            this.Age = 0;
        }
    }

}