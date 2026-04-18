return {
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "-" },
        changedelete = { text = "~" },
        untracked = { text = "|" },
      },
      signs_staged_enable = true,
      signcolumn = true,
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text_pos = "eol",
        delay = 500,
      },
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")
        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        -- 导航
        map("n", "]h", function() gitsigns.nav_hunk("next") end, "󰊢 下一个修改块")
        map("n", "[h", function() gitsigns.nav_hunk("prev") end, "󰊢 上一个修改块")

        -- 操作
        map("n", "<leader>hs", gitsigns.stage_hunk, "󰊢 暂存修改块")
        map("n", "<leader>hr", gitsigns.reset_hunk, "󰒍 重置修改块")
        map("n", "<leader>hS", gitsigns.stage_buffer, "󰊢 暂存整个文件")
        map("n", "<leader>hR", gitsigns.reset_buffer, "󰒍 重置整个文件")
        map("n", "<leader>hp", gitsigns.preview_hunk, "󰊢 预览修改块")
        map("n", "<leader>hb", function() gitsigns.blame_line({ full = true }) end, "󰕈 查看 Blame")
        map("n", "<leader>hd", gitsigns.diffthis, "󰊢 查看 Diff")
        map("n", "<leader>hD", function() gitsigns.diffthis("~") end, "󰊢 查看 Diff (~)")

        -- 开关
        map("n", "<leader>tb", gitsigns.toggle_current_line_blame, "󰕈 切换 Blame 显示")
        map("n", "<leader>td", gitsigns.toggle_deleted, "󰊢 切换已删除行显示")

        -- 文本对象
        map({ "o", "x" }, "ih", gitsigns.select_hunk, "󰊢 选择修改块")
      end,
    },
  },
}
