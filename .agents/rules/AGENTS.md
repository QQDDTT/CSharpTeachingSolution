---
trigger: always_on
description: "基础项目开发规范"
---

# 项目开发规范

## 1. 核心架构约束 (Core Architecture Constraints)
- **本地定位**: 本地开发环境（宿主机）仅作为**轻量级代码编辑与版本控制节点**。
- **GCP 优先原则 (GCP Cloud-First)**: 所有构建、环境打包及运行任务**推荐通过 GCP 调度技能转交至云端节点全权执行**。

## 2. 行为准则 (Behavioral Guidelines)
- 在执行代码编译或启动服务等指令时，Agent 应该自动挂载或使用云端调度工具，将任务派发至 GCP 服务器。
- 不推荐在本地进行重度计算或大体积依赖下载。

## 3. 设计规范要求
- **全中文化**: 所有面向用户的日志、文档以及代码注释必须遵守中文规范（见全局约束）。

## 4. 服务部署方式与终端设备规范 (Deployment & Terminal Spec)
- **服务形态与部署属性**: 本项目为 **C# 多模块教学示例解决方案**（通用系统/教学方案），核心职能为算法演示、控制台教学（MainApp）与轻量 Web 教学模块（MainWeb）。属于**本地开发学习与模块测试类型，免云端公网生产部署 (No Production Cloud Deployment)**，无需绑定域名或对外开放微服务；
- **终端设备支持范围**: 教学与测试场景**专供 PC 开发者工作站（Windows 桌面环境与终端控制台）**使用，Web 教学模块面向桌面端现代浏览器本地调试（`localhost`），不作为面向移动端用户的生产系统交付。

## 5. 全域统一条款 (Workspace-wide Clauses)
- **README 规范**: 遵循 Evopoiesis/docs/specs/07-readme-convention.md（根 README 仅作简介，一级目录 README 写内容与目录结构，二级及以下目录禁止 README）。
- **GitHub 规范**: 遵循 Evopoiesis/docs/specs/08-github-conventions.md（同名仓库、main 分支、统一 SSH 远端）。
- **密钥管理**: 遵循 Evopoiesis/docs/specs/09-secrets-management.md（本地凭据留在项目目录并由 .gitignore 防提交，仓库内严禁出现真实密钥）。
