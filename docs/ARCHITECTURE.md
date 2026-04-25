# 架构设计

本项目为一个 C# 教学示例解决方案，主要分为：
- 核心控制台应用 `MainApp`
- 核心 Web 应用 `MainWeb`
- 各类知识点教学模块 `Module.*` 和 `Web.*`

## 模块通信机制

各教学模块提供基础逻辑与练习，`MainApp` 或 `MainWeb` 会通过程序集引用（Project Reference）的方式调用各教学模块的接口或业务类。
