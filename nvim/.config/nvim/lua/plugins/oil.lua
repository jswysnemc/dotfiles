return {
  {
    "stevearc/oil.nvim",
    dependencies = { "echasnovski/mini.icons" },
    lazy = false,
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      view_options = {
        show_hidden = true,
      },
      skip_confirm_for_simple_edits = true,
      delete_to_trash = true,
      lsp_file_methods = {
        enabled = true,
        timeout_ms = 1000,
      },
      float = {
        padding = 2,
        max_width = 0.5,
        max_height = 0.8,
        border = "rounded",
      },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "󰉋 打开上级目录" },
      { "<leader>fe", "<cmd>Oil<cr>", desc = "󰈔 文件管理器" },
    },
  },
}
