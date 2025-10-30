namespace Module.Zoo
{
    class Dog : Animal<Dog>
    {
        private readonly static Random random = new Random();
        public readonly static Food[] Foods = { Food.Bone, Food.Meet };
        public string Name { get; set; } = "dog";
        public Gender Gender { get; set; } = Gender.Male;
        public Color Color { get; set; } = Color.White;
        public Dog? Father;
        public Dog? Mother;
        public void eat()
        {
            Console.WriteLine("I'm eating {}", Foods[random.Next(0, Foods.Length)]);
        }

        public void run()
        {
            Console.WriteLine("I'm running...");
        }

        public static Dog operator +(Dog a, Dog b)
        {
            if (a.Gender != b.Gender)
            {
                Dog puppy = new Dog();
                puppy.Father = a.Gender == Gender.Male ? a : b;
                puppy.Mother = a.Gender == Gender.Female ? a : b;
                puppy.Name = "puppy";
                return puppy;
            }
            throw new ApplicationException("Gender Error!");
        }
    }
}