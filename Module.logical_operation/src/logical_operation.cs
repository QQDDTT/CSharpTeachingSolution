using System;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Runtime.ConstrainedExecution;
using System.Text;

namespace Module.logical_operation
{
    public class Logical_operation
    {
        public static void Main(string[] args)
        {
            ExpressionBuilder builder = new ExpressionBuilder(3, 3, false);
            builder.Generate();
            Console.WriteLine("变量: " + builder.GetVariableString());
            Console.Read();
            Console.WriteLine("表达式: " + builder.GetExpressionString());
            Console.Read();
            Console.WriteLine("结果: " + builder.Result);
        }
    }

    public class ExpressionBuilder
    {
        private static readonly string BOOL_ECPR = "BOOL_EXPR";
        private Random random = new Random();

        // ===== 类属性 =====
        public int ExpressionLength { get; private set; }          // 算式长度，变量符号个数
        public int VariableCount { get; private set; }             // 变量个数
        public bool UseRelationalOperators { get; private set; }   // 是否使用关系运算符
        public string Expression { get; private set; } = "";       // 生成的表达式字符串
        public VariableTable Variables { get; private set; }          // 变量数组

        // ===== 构造函数 =====
        public ExpressionBuilder(int expressionLength, int variableCount, bool useRelOps = false)
        {
            if (variableCount < 2) throw new ArgumentException("变量个数必须 >= 2");
            if (expressionLength < 2) throw new ArgumentException("算式长度必须 >= 2");
            if (variableCount > expressionLength) throw new ArgumentException("变量个数不能大于算式长度");
            if (useRelOps && (expressionLength % 2 != variableCount % 2))
                throw new ArgumentException("使用关系运算符时，算式长度与变量个数必须同奇偶性");
            ExpressionLength = expressionLength;
            VariableCount = variableCount;
            UseRelationalOperators = useRelOps;
            Variables = new VariableTable();
        }
        
        public bool Result
        {
            get
            {
                return Evaluate(Expression, Variables);
            }
        }

        // ===== 生成表达式 =====
        public void Generate()
        {
            Variables.Clear();
            if (UseRelationalOperators)
            {
                int boolExprMaxCount = ExpressionLength / 2;
                int boolExprRelCount = random.Next(1, boolExprMaxCount);
                int boolPlaceholdersRelCount = ExpressionLength - boolExprRelCount;
                int boolValMaxCount = ExpressionLength - boolPlaceholdersRelCount;
                int boolVarCount = boolValMaxCount == 0 ? 0 : random.Next(1, boolValMaxCount);
                int intVarCount = VariableCount - boolVarCount;
                // Console.WriteLine($"表达式长度: {ExpressionLength}, 变量数: {VariableCount}");
                // Console.WriteLine($"布尔变量数: {boolVarCount}, 整型变量数: {intVarCount}, 关系表达式数: {boolPlaceholdersRelCount}");
                for (int i = 0; i < VariableCount; i++)
                {
                    char varName = (char)('A' + i);
                    if (i < boolVarCount)
                    {
                        Variables.AddVariable(new Variable(varName.ToString(), typeof(bool), random.Next(2) == 0));
                    }
                    else
                    {
                        int intValue = random.Next(0, 100);
                        Variables.AddVariable(new Variable(varName.ToString(), typeof(int), intValue));
                    }
                }

                // 生成布尔占位表达式（逻辑骨架）
                string[] boolPlaceholders = new string[boolPlaceholdersRelCount];

                // 随机选择哪些位置放 BOOL_EXPR
                HashSet<int> exprPositions = new HashSet<int>();
                while (exprPositions.Count < boolExprRelCount)
                {
                    int pos = random.Next(0, boolPlaceholdersRelCount - 1); 
                    exprPositions.Add(pos);
                }
                for (int i = 0; i < boolPlaceholdersRelCount; i++)
                {
                    if (exprPositions.Contains(i))
                    {
                        // 关系表达式占位符
                        boolPlaceholders[i] = BOOL_ECPR;
                    }
                    else
                    {
                        // 选择一个布尔变量
                        string name;
                        Type? varType;
                        do
                        {
                            name = Variables.GetName(random.Next(VariableCount));
                            varType = Variables.GetType(name);
                        }
                        while (varType != typeof(bool)); // 必须是 bool 类型变量

                        boolPlaceholders[i] = name;
                    }
                }
                string skeleton = GenerateWithoutRalationalOperators(boolPlaceholders, random);
                // Console.WriteLine("逻辑骨架: " + skeleton);
                // 替换占位符为关系表达式
                string[] intVars = new string[intVarCount];
                for (int i = 0; i < intVarCount; i++)
                {
                    intVars[i] = Variables.GetName(i + boolVarCount);
                }
                Expression = RaplaceBoolExperssion(skeleton, intVars, random);
            }
            else
            {
                string[] vars = new string[ExpressionLength];
                // 纯逻辑运算：变量是 bool
                for (int i = 0; i < VariableCount; i++)
                {
                    char varName = (char)('A' + i);
                    Variables.AddVariable(new Variable(varName.ToString(), typeof(bool), random.Next(2) == 0));
                }

                for (int i = 0; i < ExpressionLength; i++)
                {
                    vars[i] = Variables.GetName(random.Next(VariableCount));
                }
                // 2. 直接生成表达式
                Expression = GenerateWithoutRalationalOperators(vars, random);
            }
        }

        // ===== 表达式求值 =====
        public static bool Evaluate(string expr, VariableTable vars)
        {
            // 替换变量
            foreach (var kv in vars)
            {
                string replacement;
                if (kv.VarType == typeof(int))
                    replacement = kv.Value.ToString()!;  // int
                else
                    replacement = (bool)kv.Value ? "true" : "false"; // bool

                expr = expr.Replace(kv.Name, replacement);
            }

            // 替换逻辑运算符为 DataTable 可识别形式
            expr = expr.Replace("&&", " AND ").Replace("||", " OR ").Replace("!", " NOT ").Replace("==", "=");

            using (var table = new DataTable())
            {
                object result = table.Compute(expr, "");
                return Convert.ToBoolean(result);
            }
        }

        // ===== 获取表达式字符串 =====
        public string GetExpressionString()
        {
            return Expression;
        }

        // ===== 获取变量赋值字符串 =====
        public string GetVariableString()
        {
            StringBuilder sb = new StringBuilder();
            foreach (var kv in Variables)
            {
                sb.Append($"{kv.Name}={kv.Value}, ");
            }
            return sb.ToString().TrimEnd(',', ' ');
        }

        private static String GenerateWithoutRalationalOperators(string[] vars, Random random)
        {
            StringBuilder exprBuilder = new StringBuilder();
            int openParens = 0;
            for (int i = 0; i < vars.Length; i++)
            {
                if (i > 0)
                {
                    exprBuilder.Append(random.Next(2) == 0 ? " && " : " || ");
                }

                bool useNot = random.Next(3) == 0;
                string varName = vars[i];

                // 随机决定是否加括号
                bool addParen = random.Next(100) < 30; // 30% 概率加括号
                if (addParen)
                {
                    exprBuilder.Append("(");
                    openParens++;
                }

                if (useNot)
                {
                    exprBuilder.Append("!");
                }
                exprBuilder.Append(varName);

                // 随机决定是否在这里关闭括号（但前提是有未闭合的括号）
                if (openParens > 0 && random.Next(100) < 50)
                {
                    exprBuilder.Append(")");
                    openParens--;
                }
            }

            // 收尾：如果还有没闭合的括号，就补上
            while (openParens > 0)
            {
                exprBuilder.Append(")");
                openParens--;
            }
            return exprBuilder.ToString();
        }

        // ===== 替换关系表达式 =====
        private static String RaplaceBoolExperssion(String expr, string[] vars, Random random)
        {
            string[] ops = { ">", "<", ">=", "<=", "==", "!=" };
            string left, right;
            while (expr.Contains(BOOL_ECPR))
            {
                do
                {
                    left = vars[random.Next(vars.Length)];
                    right = vars[random.Next(vars.Length)];
                }
                while (right == left);
                string op = ops[random.Next(ops.Length)];
                expr = expr.Replace(BOOL_ECPR, $"({left} {op} {right})", StringComparison.Ordinal);
            }
            return expr;
        }
    }

    public class Variable
    {
        public string Name { get; private set; }
        public Type VarType { get; private set; }
        public object Value { get; private set; }

        public Variable(string name, Type type, object value)
        {
            Name = name;
            VarType = type;
            Value = value;
        }
    }
    public class VariableTable : IEnumerable<Variable>
    {
        private List<Variable> variables = new List<Variable>();

        public void AddVariable(Variable variable)
        {
            variables.Add(variable);
        }

        public string GetName(int index)
        {
            if (index < 0 || index >= variables.Count)
                throw new IndexOutOfRangeException("变量索引超出范围");
            return variables[index].Name;
        }

        public Type? GetType(string name)
        {
            var varObj = variables.FirstOrDefault(v => v.Name == name);
            return varObj?.VarType;
        }

        public object? GetValue(string name)
        {
            var varObj = variables.FirstOrDefault(v => v.Name == name);
            return varObj?.Value;
        }

        public void Clear()
        {
            variables.Clear();
        }

        public IEnumerable<Variable> GetAll()
        {
            return variables;
        }

        public override string ToString()
        {
            return string.Join(", ", variables);
        }
            // ===== 实现 IEnumerable<Variable> =====
        public IEnumerator<Variable> GetEnumerator()
        {
            return variables.GetEnumerator();
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return GetEnumerator();
        }
    }
}
