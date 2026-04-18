return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      picker = { enabled = false },
      explorer = { enabled = true },

      dashboard = {
        enabled = true,
        preset = {
          header = table.concat({
            "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
            "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
            "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
            "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
            "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
          }, "\n"),
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
          {
            align = "center",
            text = {
              { "\n " },
              { "Help poor children in Uganda!", hl = "NonText" },
              { "\n " },
              { "type  :help iccf<Enter>       for information ", hl = "NonText" },
              { "\n " },
              { "type  :q<Enter>               to exit         ", hl = "NonText" },
            },
            padding = 1,
          },
        },
      },
      notifier = {
        enabled = true,
        timeout = 3000,
      },
      quickfile = { enabled = true },
      bigfile = { enabled = true },
      scope = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      scroll = {
        enabled = true,
        animate = {
          duration = { step = 10, total = 200 },
          easing = "linear",
        },
        animate_repeat = {
          delay = 100,
          duration = { step = 5, total = 50 },
          easing = "linear",
        },
      },
    },
    keys = {
      { "<leader>e", function() Snacks.explorer() end, desc = "󰈔 文件树" },
      { "<c-/>", function() Snacks.terminal() end, desc = "󰅇 浮动终端", mode = { "n", "t" } },
      { "<leader>gg", function() Snacks.lazygit() end, desc = "󰊢 Lazygit" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "󰊈 在浏览器中打开", mode = { "n", "v" } },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "󰅩 关闭 缓冲区" },
      { "<leader>n", function() Snacks.notifier.show_history() end, desc = "󰿟 通知历史" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "󰿟 清除通知" },
      { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "󰝆 下一个引用" },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "󰝆 上一个引用" },
    },
  },
}
