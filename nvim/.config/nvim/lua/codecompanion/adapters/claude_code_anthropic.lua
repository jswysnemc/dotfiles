local helpers = require("codecompanion.adapters.acp.helpers")

-- 从 Claude Code 配置文件中加载环境变量
local function load_claude_settings()
  local path = vim.fn.expand("~/.claude/settings.json")
  local f = io.open(path, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok then return {} end
  return data.env or {}
end

local settings = load_claude_settings()

---@class CodeCompanion.ACPAdapter.ClaudeCodeAnthropic: CodeCompanion.ACPAdapter
return {
  name = "claude_code_anthropic",
  formatted_name = "Claude Code (Anthropic API)",
  type = "acp",
  roles = {
    llm = "assistant",
    user = "user",
  },
  opts = {
    vision = true, -- 支持图片输入
    trim_tool_output = true, -- 裁剪工具输出
  },
  commands = {
    -- ACP 协议启动命令
    default = {
      "timeout", "60", "npx", "--yes", "@zed-industries/claude-code-acp",
    },
  },
  defaults = {
    mcpServers = {}, -- MCP 服务器配置
    timeout = 20000,
    auth_method = "api-key", -- 认证方式
  },
  env = {
    ANTHROPIC_API_KEY = settings.ANTHROPIC_AUTH_TOKEN or "",
    ANTHROPIC_API_URL = settings.ANTHROPIC_BASE_URL and vim.trim(settings.ANTHROPIC_BASE_URL) or "",
    ANTHROPIC_MODEL = settings.ANTHROPIC_MODEL or "",
    ANTHROPIC_SMALL_FAST_MODEL = settings.ANTHROPIC_DEFAULT_HAIKU_MODEL or "",
  },
  parameters = {
    protocolVersion = 1,
    clientCapabilities = {
      fs = { readTextFile = true, writeTextFile = true },
    },
    clientInfo = {
      name = "CodeCompanion.nvim",
      version = "1.0.0",
    },
  },
  handlers = {
    ---@param self CodeCompanion.ACPAdapter
    ---@return boolean
    setup = function(self)
      return true
    end,

    ---@param self CodeCompanion.ACPAdapter
    ---@return boolean
    auth = function(self)
      local key = self.env_replaced.ANTHROPIC_API_KEY
      if not key or key == "" then
        vim.notify("ANTHROPIC_API_KEY not set, authentication may fail", vim.log.levels.WARN)
        return false
      end

      vim.env.ANTHROPIC_API_KEY = key

      local url = self.env_replaced.ANTHROPIC_API_URL
      if url and url ~= "" then
        vim.env.ANTHROPIC_API_URL = url
      end

      local model = self.env_replaced.ANTHROPIC_MODEL
      if model and model ~= "" then
        vim.env.ANTHROPIC_MODEL = model
      end

      local small = self.env_replaced.ANTHROPIC_SMALL_FAST_MODEL
      if small and small ~= "" then
        vim.env.ANTHROPIC_SMALL_FAST_MODEL = small
      end

      vim.env.CLAUDE_CODE_USE_API_KEY = "true"
      return true
    end,

    ---@param self CodeCompanion.ACPAdapter
    ---@param messages table
    ---@param capabilities table
    ---@return table
    form_messages = function(self, messages, capabilities)
      return helpers.form_messages(self, messages, capabilities)
    end,

    ---@param self CodeCompanion.ACPAdapter
    ---@param code number
    ---@return nil
    on_exit = function(self, code) end,
  },
}
