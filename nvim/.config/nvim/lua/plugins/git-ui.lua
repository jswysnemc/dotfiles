-- Git 界面（Neogit + Diffview）
return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "echasnovski/mini.icons",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gn", "<cmd>Neogit<cr>", desc = "󰊢 Neogit" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "󰊢 Git 提交" },
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "󰊢 Diff 视图" },
      { "<leader>gD", "<cmd>DiffviewFileHistory %<cr>", desc = "󰈑 文件历史" },
    },
    opts = {
      graph_style = "unicode",
      kind = "tab",
      signs = {
        section = { "", "" },
        item = { "", "" },
        hunk = { "", "" },
      },
      integrations = {
        diffview = true,
      },
    },
  },
}
