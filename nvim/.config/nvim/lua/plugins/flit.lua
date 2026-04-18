-- 改进的单词移动（按子词跳转）
return {
  {
    "chrisgrieser/nvim-spider",
    event = "VeryLazy",
    keys = {
      { "w", "<cmd>lua require('spider').motion('w')<cr>", desc = "󰈋 下一个词首" },
      { "e", "<cmd>lua require('spider').motion('e')<cr>", desc = "󰈋 下一个词尾" },
      { "b", "<cmd>lua require('spider').motion('b')<cr>", desc = "󰈋 上一个词首" },
      { "ge", "<cmd>lua require('spider').motion('ge')<cr>", desc = "󰈋 上一个词尾" },
    },
  },
}
