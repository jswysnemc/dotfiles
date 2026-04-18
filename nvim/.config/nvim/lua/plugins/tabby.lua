return {
  {
    "nanozuki/tabby.nvim",
    event = "VeryLazy",
    opts = function()
      local theme = {
        fill = { fg = "#6c7086", bg = "#181825" },
        head = { fg = "#89b4fa", bg = "#181825", style = "bold" },
        current = { fg = "#cdd6f4", bg = "#313244", style = "bold" },
        tab = { fg = "#7f849c", bg = "#1e1e2e" },
        win = { fg = "#cdd6f4", bg = "#181825" },
        tail = { fg = "#89b4fa", bg = "#181825" },
      }

      return {
        option = {
          buf_name = {
            mode = "tail",
          },
        },
        line = function(line)
          return {
            {
              { " 󰓩 ", hl = theme.head },
              line.sep("", theme.head, theme.fill),
            },
            line.bufs().foreach(function(buf)
              local hl = buf.is_current() and theme.current or theme.tab
              return {
                line.sep("", hl, theme.fill),
                buf.file_icon() .. " ",
                buf.name(),
                buf.is_changed() and " ●" or "",
                { " 󰅖 ", click = { "to_buf", buf.id } },
                line.sep("", hl, theme.fill),
                hl = hl,
                margin = " ",
              }
            end),
            line.spacer(),
            line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
              return {
                line.sep("", theme.win, theme.fill),
                win.is_current() and " " or " ",
                win.buf_name(),
                line.sep("", theme.win, theme.fill),
                hl = theme.win,
                margin = " ",
              }
            end),
            {
              line.sep("", theme.tail, theme.fill),
              { " ", hl = theme.tail },
            },
            hl = theme.fill,
          }
        end,
      }
    end,
    keys = {
      { "<S-h>", "<cmd>bprevious<cr>", desc = "󰉋 上一个 缓冲区" },
      { "<S-l>", "<cmd>bnext<cr>", desc = "󰉋 下一个 缓冲区" },
      { "[b", "<cmd>bprevious<cr>", desc = "󰉋 上一个 缓冲区" },
      { "]b", "<cmd>bnext<cr>", desc = "󰉋 下一个 缓冲区" },
    },
  },
}
