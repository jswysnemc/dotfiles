-- 彩虹括号匹配
return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local rainbow = require("rainbow-delimiters")

      vim.g.rainbow_delimiters = {
        -- 使用全局策略
        strategy = {
          [""] = rainbow.strategy["global"],
        },
        -- 查询类型：Lua 使用 block 级别匹配
        query = {
          [""] = "rainbow-delimiters",
          lua = "rainbow-blocks",
        },
        -- 高亮颜色组
        highlight = {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        },
      }
    end,
  },
}
