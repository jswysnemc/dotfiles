return {
  {
    "smoka7/hop.nvim",
    version = "*",
    event = "VeryLazy",
    opts = {
      multi_windows = true,
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("hop").hint_words() end, desc = "󰝆 快速跳转" },
      { "S", mode = { "n", "x", "o" }, function() require("hop").hint_lines() end, desc = "󰝆 行跳转" },
      { "r", mode = "o", function() require("hop").hint_words({ multi_windows = false }) end, desc = "󰝆 远程操作" },
    },
  },
}
