using System;
namespace Module.five_number
{
    public class Five_number
    {
        public static void Main(string[] args)
        {
            foreach (Group group in flow2(100))
            {
                Console.WriteLine(group.Format(5));
            }
        }
        public static Group[] flow1(int max)
        {
            Group[] groups = new Group[max];
            int index = 0;
            int n1, n2, n3, n4, n5;
            n1 = 1;
            while (index < max)
            {
                for (n2 = n1 + 1; n2 <= 2 * n1 - 3; n2++)
                {
                    for (n3 = n2 + 1; n3 <= 2 * n1 - 2; n3++)
                    {
                        for (n4 = n3 + 1; n4 <= 2 * n1 - 1; n4++)
                        {
                            for (n5 = n4 + 1; n5 <= 2 * n1; n5++)
                            {
                                try
                                {
                                    groups[index] = Group.Create(n1, n2, n3, n4, n5);
                                    index++;
                                }
                                catch (Exception)
                                {
                                }
                            }
                        }
                    }
                }
                n1++;
            }

            return groups;
        }

        public static Group[] flow2(int max)
        {
            Group[] groups = new Group[max];
            int index = 0;
            int n1, n2, n3, n4, n5;
            n1 = 1;
            while (index < max)
            {
                for (n2 = n1 + 1; n2 <= 2 * n1 - 3; n2++)
                {
                    if (!Group.IsRelation(n1, n2)) continue;
                    for (n3 = n2 + 1; n3 <= 2 * n1 - 2; n3++)
                    {
                        if (!Group.IsRelation(n1, n3)) continue;
                        if (!Group.IsRelation(n2, n3)) continue;
                        for (n4 = n3 + 1; n4 <= 2 * n1 - 1; n4++)
                        {
                            if (!Group.IsRelation(n1, n4)) continue;
                            if (!Group.IsRelation(n2, n4)) continue;
                            if (!Group.IsRelation(n3, n4)) continue;
                            for (n5 = n4 + 1; n5 <= 2 * n1; n5++)
                            {
                                if (!Group.IsRelation(n1, n5)) continue;
                                if (!Group.IsRelation(n2, n5)) continue;
                                if (!Group.IsRelation(n3, n5)) continue;
                                if (!Group.IsRelation(n4, n5)) continue;
                                if (index < max)
                                    groups[index++] = new Group(n1, n2, n3, n4, n5);
                            }
                        }
                    }
                }
                n1++;
            }

            return groups;
        }
    }



    public class Group
    {
        private int n1, n2, n3, n4, n5;
        public Group(int n1, int n2, int n3, int n4, int n5)
        {
            this.n1 = n1;
            this.n2 = n2;
            this.n3 = n3;
            this.n4 = n4;
            this.n5 = n5;
        }

        public static Group Create(int n1, int n2, int n3, int n4, int n5)
        {
            if (
                IsRelation(n1, n2) &&
                IsRelation(n1, n3) &&
                IsRelation(n1, n4) &&
                IsRelation(n1, n5) &&
                IsRelation(n2, n3) &&
                IsRelation(n2, n4) &&
                IsRelation(n2, n5) &&
                IsRelation(n3, n4) &&
                IsRelation(n3, n5) &&
                IsRelation(n4, n5)
                )
            {
                return new Group(n1, n2, n3, n4, n5);
            }
            throw new Exception();
        }

        public static bool IsRelation(int a, int b)
        {
            if (a > 0 && b > 0 && a != b)
            {
                int i = a > b ? a - b : b - a;
                if (a % i == 0)
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
            return false;
        }

        public string Format(int len)
        {
            return $"{n1.ToString().PadLeft(len)} {n2.ToString().PadLeft(len)} {n3.ToString().PadLeft(len)} {n4.ToString().PadLeft(len)} {n5.ToString().PadLeft(len)}";
        }
    }
}
