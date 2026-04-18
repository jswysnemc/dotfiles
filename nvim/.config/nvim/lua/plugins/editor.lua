return {
  -- 图标
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- 快捷键提示
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>a", group = "󰊕 AI 助手" },
        { "<leader>b", group = "󰉋 缓冲区" },
        { "<leader>c", group = "󰊄 代码" },
        { "<leader>d", group = " 调试" },
        { "<leader>f", group = "󰈞 查找" },
        { "<leader>g", group = " 版本控制" },
        { "<leader>h", group = "󰊢 修改块" },
        { "<leader>s", group = "󰍉 搜索" },
        { "<leader>q", group = "󰗼 会话/退出" },
        { "<leader>t", group = "󱁤 工具" },
        { "<leader>u", group = "󰅇 界面" },
        { "<leader>x", group = "󰒁 诊断" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "󰌗 当前 缓冲区 快捷键",
      },
    },
  },

  -- TODO/FIXME 高亮和搜索
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",
    opts = {
      keywords = {
        TODO = { icon = "T ", color = "info" },
        FIX = { icon = "F ", color = "error" },
        FIXME = { icon = "F ", color = "error" },
        HACK = { icon = "H ", color = "warning" },
        WARN = { icon = "W ", color = "warning" },
        PERF = { icon = "P ", color = "default" },
        NOTE = { icon = "N ", color = "hint" },
        TEST = { icon = "t ", color = "test" },
      },
    },
    keys = {
      { "<leader>st", "<cmd>TodoFzfLua<cr>", desc = "󰒁 待办事项" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "󰝆 下一个待办" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "󰝆 上一个待办" },
    },
  },

  -- Treesitter 注释
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- 自动配对括号
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    opts = {},
  },

  -- 增强文本对象
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = {},
  },

  -- 包围操作 (添加/修改/删除括号引号)
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "sa",
        delete = "sd",
        find = "sf",
        find_left = "sF",
        highlight = "sh",
        replace = "sr",
        update_n_lines = "sn",
      },
    },
  },

  -- 会话管理
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "󰓎 恢复会话" },
      { "<leader>qS", function() require("persistence").select() end, desc = "󰓎 选择会话" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "󰓎 上次会话" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "󰓎 停止会话保存" },
    },
  },
}
