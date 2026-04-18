-- 高亮十六进制颜色值（如 #ff0000 会显示对应颜色背景）
return {
  {
    "echasnovski/mini.hipatterns",
    event = "VeryLazy",
    opts = function()
      local hipatterns = require("mini.hipatterns")
      return {
        highlighters = {
          hex_color = hipatterns.gen_highlighter.hex_color(), -- 自动识别 HEX 颜色
        },
      }
    end,
  },
}
