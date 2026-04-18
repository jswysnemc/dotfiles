return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.icons" },
    cmd = "FzfLua",
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "󰈞 查找文件" },
      { "<leader>/", "<cmd>FzfLua live_grep<cr>", desc = "󰍉 全局搜索" },
      { "<leader>,", "<cmd>FzfLua buffers<cr>", desc = "󰉋 缓冲区 列表" },
      { "<leader>:", "<cmd>FzfLua command_history<cr>", desc = "󰋖 命令历史" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "󰈑 最近文件" },
      { "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "󰍉 全局搜索" },
      { "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "󰍉 搜索当前词" },
      { "<leader>sb", "<cmd>FzfLua lgrep_curbuf<cr>", desc = "󰍉 当前文件搜索" },
      { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "󰌗 快捷键列表" },
      { "<leader>sh", "<cmd>FzfLua helptags<cr>", desc = "󰋖 帮助文档" },
      { "<leader>sc", "<cmd>FzfLua commands<cr>", desc = "󰈮 命令列表" },
      { "<leader>sr", "<cmd>FzfLua resume<cr>", desc = "󰈞 恢复上次搜索" },
      { "<leader>st", "<cmd>TodoFzfLua<cr>", desc = "󰒁 待办事项" },
      { "<leader>ss", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "󰊄 文档符号" },
      { "<leader>sS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "󰊄 工作区符号" },
      { "<leader>sdd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "󰒁 工作区诊断" },
      { "<leader>sdb", "<cmd>FzfLua diagnostics_document<cr>", desc = "󰒁 文件诊断" },
    },
    opts = function()
      return {
        "fzf-native",
        winopts = {
          border = "rounded",
          preview = {
            layout = "vertical",
            border = "border",
          },
          height = 0.90,
          width = 0.90,
        },
        files = {
          prompt = "文件> ",
          file_icons = true,
          git_icons = false,
        },
        grep = {
          prompt = "搜索> ",
          rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e",
        },
        buffers = {
          prompt = "Buffer> ",
          sort_lastused = true,
        },
      }
    end,
  },
}
