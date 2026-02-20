# API 接口规范

本项目的主要 API 包括各教学模块公开的方法，以及可能通过 `MainWeb` 展示的 RESTful 接口。

## 规范

- 响应统一采用 JSON 格式。
- API 路径使用小写字母配合中划线（例如 `/api/v1/user-info`）。
- 错误处理返回统一的 `ErrorCode` 和 `ErrorMessage`。
