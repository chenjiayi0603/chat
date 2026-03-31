#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CONFIG_DIR="$ROOT_DIR/config"
DEFAULT_LOG_DIR="$ROOT_DIR/_output/logs"
OPENIM_SERVER_ROOT="${OPENIM_SERVER_ROOT:-$(cd "$ROOT_DIR/../open-im-server" && pwd)}"
DEPS_COMPOSE_FILE="${DEPS_COMPOSE_FILE:-$OPENIM_SERVER_ROOT/docker-compose.yml}"

# ======================== 使用例子（快速复制） ========================
# 基础运维（openim-chat 自身）
#   ./scripts/ops.sh start
#   ./scripts/ops.sh stop
#   ./scripts/ops.sh restart
#
# 全量运维（依赖 + chat）
#   ./scripts/ops.sh start-all
#   ./scripts/ops.sh stop-all
#   ./scripts/ops.sh status
#
# 依赖容器管理（复用 open-im-server 的 docker-compose.yml）
#   ./scripts/ops.sh deps-up
#   ./scripts/ops.sh deps-down
#   ./scripts/ops.sh deps-ps
#
# 检查与排障
#   ./scripts/ops.sh check
#   ./scripts/ops.sh logs
#   ./scripts/ops.sh logs chat-api-0.log
#   ./scripts/ops.sh ps
#   ./scripts/ops.sh ports
# =====================================================================

usage() {
  cat <<'EOF'
openim-chat 运维脚本

用法:
  ./scripts/ops.sh <命令> [参数]

命令:
  deps-up                 启动第三方依赖容器（Mongo/Redis/Etcd/Kafka/MinIO/Web）
  deps-down               停止第三方依赖容器
  deps-ps                 查看第三方依赖容器状态
  start                   启动 openim-chat 服务（mage start）
  stop                    停止 openim-chat 服务（mage stop）
  restart                 重启 openim-chat 服务（stop + start）
  start-all               启动依赖 + openim-chat
  stop-all                停止 openim-chat + 依赖容器
  status                  检查 openim-chat + 依赖容器状态
  check                   执行 openim-chat 健康检查（mage check）
  logs [file]             查看日志；无参数显示目录，有参数 tail 指定日志文件
  ps                      查看 openim-chat 相关进程
  ports                   查看 openim-chat 相关监听端口
  help                    显示帮助

环境变量:
  CONFIG_DIR              默认: ./config
  LOG_DIR                 默认: ./_output/logs
  OPENIM_SERVER_ROOT      默认: ../open-im-server
  DEPS_COMPOSE_FILE       默认: $OPENIM_SERVER_ROOT/docker-compose.yml
EOF
}

log() {
  echo "[chat-ops] $*"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1" >&2
    exit 1
  fi
}

compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi
  echo "未找到 docker compose / docker-compose" >&2
  exit 1
}

run_compose() {
  if [[ ! -f "$DEPS_COMPOSE_FILE" ]]; then
    echo "依赖 compose 文件不存在: $DEPS_COMPOSE_FILE" >&2
    exit 1
  fi
  local compose
  compose="$(compose_cmd)"
  # shellcheck disable=SC2086
  $compose -f "$DEPS_COMPOSE_FILE" "$@"
}

# 示例: ./scripts/ops.sh deps-up
# 启动依赖容器节点:
#   mongodb, redis, etcd, kafka, minio, openim-web-front
deps_up() {
  log "启动第三方依赖容器..."
  run_compose up -d mongodb redis etcd kafka minio openim-web-front
}

# 示例: ./scripts/ops.sh deps-down
deps_down() {
  log "停止第三方依赖容器..."
  run_compose down
}

# 示例: ./scripts/ops.sh deps-ps
deps_ps() {
  log "第三方依赖容器状态:"
  run_compose ps
}

# 示例: ./scripts/ops.sh start
# 启动 openim-chat 节点:
#   chat-api, chat-rpc, admin-api, admin-rpc, bot-api, bot-rpc
start_server() {
  need_cmd mage
  local config_dir="${CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
  log "启动 openim-chat 服务，配置目录: $config_dir"
  (
    cd "$ROOT_DIR"
    OPENIMCONFIG="$config_dir" mage start
  )
}

# 示例: ./scripts/ops.sh stop
stop_server() {
  need_cmd mage
  log "停止 openim-chat 服务..."
  (
    cd "$ROOT_DIR"
    mage stop
  )
}

# 示例: ./scripts/ops.sh check
check_server() {
  need_cmd mage
  log "检查 openim-chat 服务状态..."
  (
    cd "$ROOT_DIR"
    mage check
  )
}

# 示例: ./scripts/ops.sh status
# 执行:
#   1) mage check
#   2) docker compose ps (第三方依赖)
status_all() {
  log "openim-chat 服务状态:"
  if ! check_server; then
    echo "openim-chat 服务检查失败，请查看日志。" >&2
  fi
  echo
  deps_ps
}

# 示例:
#   ./scripts/ops.sh logs
#   ./scripts/ops.sh logs chat-api-0.log
logs_all() {
  local log_dir="${LOG_DIR:-$DEFAULT_LOG_DIR}"
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    if [[ -d "$log_dir" ]]; then
      log "日志目录: $log_dir"
      ls -la "$log_dir"
      return
    fi
    echo "日志目录不存在: $log_dir" >&2
    exit 1
  fi

  local target="$log_dir/$file"
  if [[ ! -f "$target" ]]; then
    echo "日志文件不存在: $target" >&2
    exit 1
  fi
  log "实时查看日志: $target"
  tail -f "$target"
}

# 示例: ./scripts/ops.sh ps
ps_chat() {
  log "openim-chat 相关进程:"
  ps -ef | awk '
    NR==1 {print; next}
    tolower($0) ~ /openim-chat|chat-api|chat-rpc|admin-api|admin-rpc|bot-api|bot-rpc/ {print}
  '
}

# 示例: ./scripts/ops.sh ports
ports_chat() {
  log "openim-chat 相关监听端口:"
  ss -lntp | awk '
    NR==1 {print; next}
    tolower($0) ~ /chat-api|chat-rpc|admin-api|admin-rpc|bot-api|bot-rpc|openim-chat/ {print}
  '
}

cmd="${1:-help}"
case "$cmd" in
  deps-up)
    deps_up
    ;;
  deps-down)
    deps_down
    ;;
  deps-ps)
    deps_ps
    ;;
  start)
    start_server
    ;;
  stop)
    stop_server
    ;;
  restart)
    stop_server
    start_server
    ;;
  start-all)
    deps_up
    start_server
    ;;
  stop-all)
    stop_server || true
    deps_down
    ;;
  status)
    status_all
    ;;
  check)
    check_server
    ;;
  logs)
    logs_all "${2:-}"
    ;;
  ps)
    ps_chat
    ;;
  ports)
    ports_chat
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "未知命令: $cmd" >&2
    echo
    usage
    exit 1
    ;;
esac
