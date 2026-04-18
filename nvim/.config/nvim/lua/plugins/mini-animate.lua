-- 窗口/光标动画效果
return {
  {
    "echasnovski/mini.animate",
    version = false,
    event = "VeryLazy",
    opts = function()
      local animate = require("mini.animate")
      return {
        scroll = { enable = false }, -- 禁用滚动动画（由 snacks.scroll 替代）
        cursor = {
          timing = animate.gen_timing.linear({ duration = 80, unit = "total" }), -- 光标移动动画
        },
        resize = {
          timing = animate.gen_timing.linear({ duration = 100, unit = "total" }), -- 窗口调整动画
        },
        open = {
          timing = animate.gen_timing.linear({ duration = 80, unit = "total" }), -- 窗口打开动画
        },
        close = {
          timing = animate.gen_timing.linear({ duration = 80, unit = "total" }), -- 窗口关闭动画
        },
      }
    end,
  },
}
