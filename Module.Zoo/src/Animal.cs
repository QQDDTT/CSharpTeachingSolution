namespace Module.Zoo
{
    interface Animal<SubClass> where SubClass : Animal<SubClass>
    {
        void run();

        void eat();
        static abstract SubClass operator +(SubClass a, SubClass b);
    }
}