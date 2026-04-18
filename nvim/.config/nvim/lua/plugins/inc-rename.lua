-- 实时预览重命名（输入时即时显示重命名效果）
return {
  {
    "smjonas/inc-rename.nvim",
    event = "VeryLazy",
    opts = {
      input_buffer_type = "dressing", -- 使用 dressing.nvim 作为输入框
    },
  },
}
