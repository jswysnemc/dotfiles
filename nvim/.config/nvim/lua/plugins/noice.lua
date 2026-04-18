return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
    },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
      },
      routes = {
        {
          filter = { event = "msg_show", kind = "search_count" },
          opts = { skip = true },
        },
        {
          filter = { event = "msg_show", find = "written" },
          opts = { skip = true },
        },
      },
    },
    keys = {
      { "<leader>nn", "<cmd>Noice dismiss<cr>", desc = "󰿟 清除消息" },
      { "<leader>nh", "<cmd>Noice history<cr>", desc = "󰿟 消息历史" },
      { "<leader>nl", "<cmd>Noice last<cr>", desc = "󰿟 最后一条消息" },
    },
  },
}
