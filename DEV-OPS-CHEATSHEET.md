# openim-chat 开发机日常运维速查

工作目录示例：

- 本仓库常见路径：`/home/administrator/openim/openim-chat`（按你本机实际 `cd` 即可）

## 0. 环境变量与「完整停编启」（改代码后推荐）

在 `openim-chat` 目录下执行：

```bash
cd /home/administrator/openim/openim-chat
export OPENIMCONFIG="${OPENIMCONFIG:-$PWD/config}"

mage stop          # 停掉当前 chat 全套进程
mage build         # 编译全部 cmd 二进制（含 admin-api / admin-rpc 等）
mage start         # 检查依赖并启动全套 chat 服务
```

可选：`mage check` 做健康检查。

## 1. 启动 / 停止 / 重启

- 首次或代码变更后启动：
  - `mage build && mage start && mage check`
- 只启动（不重编译）：
  - `mage start && mage check`
- 停止：
  - `mage stop`
- 重启（推荐）：
  - `mage stop && mage start && mage check`
- 强制重启（含重编译）：
  - `mage stop && mage build && mage start && mage check`

## 2. 健康检查

- 官方检查：
  - `mage check`
- 进程检查：
  - 已安装 ripgrep：`ps -ef | rg "chat-api|chat-rpc|admin-api|admin-rpc|bot-api|bot-rpc" | rg -v rg`
  - **未安装 `rg`（仅 grep）**：`ps -ef | grep -E 'chat-api|chat-rpc|admin-api|admin-rpc|bot-api|bot-rpc' | grep -v grep`
- 端口检查：
  - 已安装 ripgrep：`ss -lntp | rg ":10008|:10009|:10010|:30200|:30300|:30400"`
  - **未安装 `rg`（仅 grep）**：`ss -lntp | grep -E ':10008|:10009|:10010|:30200|:30300|:30400'`
- **只确认管理端相关端口**（admin-api / admin-rpc）：
  - `ss -lntp | grep -E ':10009|:30200'`

## 3. 日志查看

- 查看日志目录：
  - `ls -lah _output/logs`
- 实时跟踪 chat-api：
  - `tail -f _output/logs/chat-api-0.log`
- 实时跟踪 chat-rpc：
  - `tail -f _output/logs/chat-rpc-0.log`
- 扫描错误：
  - `rg -n "error|panic|fatal|forbidden|Err|FAILED" _output/logs`
- 查看最近 100 行：
  - `tail -n 100 _output/logs/chat-api-0.log`

## 4. 接口连通性快速验证

- 登录接口可达性：
  - `curl --noproxy '*' -sS -X POST "http://127.0.0.1:10008/account/login" -H "Content-Type: application/json" -H "operationID: local-check-1" -d '{"account":"test","password":"test","platform":5}'`
- 注册接口可达性：
  - `curl --noproxy '*' -sS -X POST "http://127.0.0.1:10008/account/register" -H "Content-Type: application/json" -H "operationID: local-check-2" -d '{"platform":5,"verifyCode":"000000","autoLogin":true,"user":{"nickname":"u1","account":"u1","password":"123456"}}'`

说明：返回业务错误不一定代表服务挂了。只要有结构化 JSON 响应且无连接拒绝，通常说明服务在线。

## 5. 故障排查最短路径

当 `mage check` 失败时，按顺序执行：

1. `mage stop`
2. `mage start`
3. `mage check`
4. `ss -lntp | grep -E ':10008|:10009|:10010|:30200|:30300|:30400'`（若已装 `rg` 可把 `grep -E '...'` 换成 `rg ":10008|..."`）
5. 日志扫描：已装 `rg` 用 `rg -n "panic|fatal|bind|address already in use|error" _output/logs`；否则 `grep -nE 'panic|fatal|bind|address already in use|error' _output/logs/*.log`

## 6. 常见场景建议

- 改了配置文件：
  - `mage stop && mage start && mage check`
- 改了 Go 代码：
  - `mage stop && mage build && mage start && mage check`
- 前端登录异常：
  - 先确认 `10008` 在监听，再检查 `chat-api-0.log`

## 7. `mage build` / `mage start` 是什么

- `mage build` 做什么：
  - 编译 `cmd` / `tools` 下的服务源码，生成可执行文件到 `_output`
  - 可指定只编译部分目标，例如：`mage build chat-api chat-rpc`
  - 仅编译，不会拉起进程
- `mage start` 做什么：
  - 按 `config` 配置启动 `_output` 中的工具和服务
  - 启动后可用 `mage check` 验证健康状态
  - 默认不重新编译，通常与 `mage build` 搭配使用

一句话：`mage build && mage start` = 先产出新二进制，再用新二进制启动服务。

## 8. 怎么知道“编译了哪些文件、用哪个配置启动”

- 看构建入口（编译源头）：
  - `magefile.go` 里 `customSrcDir = "cmd"`、`customToolsDir = "tools"`，表示默认从 `cmd` 和 `tools` 目录找构建目标
  - `Build()` 调用 `mageutil.Build(bin, nil)`，`bin` 为空时通常编译默认全量目标
- 看可编译目标名：
  - `ls cmd/api cmd/rpc cmd/tools`
  - 目录名一般对应二进制名（例如 `chat-api`、`chat-rpc`、`admin-api`、`bot-api`）
- 看实际产物（编译结果）：
  - `ls -lah _output/bin/platforms/linux/amd64`
  - 能看到最终可执行文件，确认“到底编了什么”
- 看启动到底跑了什么进程：
  - 已装 `rg`：`ps -ef | rg "_output/bin|chat-api|chat-rpc|admin-api|bot-api" | rg -v rg`
  - 仅 `grep`：`ps -ef | grep -E '_output/bin|chat-api|chat-rpc|admin-api|bot-api' | grep -v grep`
  - 启动命令行会显示 `-c .../config/`，可直接看到配置目录
- 看默认配置目录：
  - `magefile.go` 里 `customConfigDir = "config"`，`Start()` 默认用项目下 `config/`
  - 常用配置文件示例：`config/chat-api-chat.yml`、`config/chat-rpc-chat.yml`、`config/discovery.yml`、`config/share.yml`
- 看某个服务具体读哪个配置：
  - 直接看该服务的 `main.go` / `start.go` 中加载配置逻辑
  - 例如 `cmd/rpc/chat-rpc/main.go` + 对应 `internal/.../start.go`

快速结论：

- “编译哪些文件” = 看 `cmd/`、`tools/` 目录 + `_output/bin/...` 产物。
- “启动用哪个配置” = 看进程启动参数里的 `-c` 路径（默认 `config/`）+ 该服务 `start.go` 读取的具体 yml。

## 9. 完整启动检查过程（实操记录模板）

按下面顺序执行并记录结果：

1. 检查 `open-im-server` 全量状态
   - `cd /home/administrator/interview-quicker/openim/open-im-server`
   - `./scripts/ops.sh status`
   - 通过标准：
     - 输出包含 `All services are running normally`
     - 端口包含 `10001`（ws）和 `10002`（api）
     - 依赖容器（mongo/redis/etcd/kafka/minio/openim-web-front）均为 `Up`

2. 检查 `openim-chat` 全量状态
   - `cd /home/administrator/openim/openim-chat`（或你的实际路径）
   - `export OPENIMCONFIG="${OPENIMCONFIG:-$PWD/config}"`（可选，与上面「§0」一致）
   - `mage check`
   - 通过标准：
     - 输出包含 `All services are running normally`
     - 关键节点端口齐全：
       - `chat-api:10008`
       - `admin-api:10009`
       - `bot-api:10010`
       - `admin-rpc:30200`
       - `chat-rpc:30300`
       - `bot-rpc:30400`

3. 失败时处理
   - `mage stop && mage start && mage check`（chat）
   - `./scripts/ops.sh restart && ./scripts/ops.sh status`（server）
   - 查看日志：
     - `openim-chat/_output/logs/*.log`
     - `open-im-server/_output/logs/*.log`
