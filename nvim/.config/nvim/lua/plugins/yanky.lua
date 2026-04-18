return {
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      highlight = { on_put = true, on_yank = true, timer = 200 },
      ring = { history_length = 100, storage = "shada" },
    },
    keys = {
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" } },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" } },
      { "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" } },
      { "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" } },
      { "<c-p>", "<Plug>(YankyPreviousEntry)", desc = "󰄧 上一个剪贴板" },
      { "<c-n>", "<Plug>(YankyNextEntry)", desc = "󰄧 下一个剪贴板" },
      { "<leader>yh", "<cmd>YankyRingHistory<cr>", desc = "󰄧 剪贴板历史" },
    },
  },
}
