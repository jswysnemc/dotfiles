return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "echasnovski/mini.icons", "catppuccin/nvim", "AndreM222/copilot-lualine" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin-mocha",
        globalstatus = true,
        disabled_filetypes = {
          statusline = { "snacks_dashboard", "snacks_explorer" },
        },
        section_separators = { left = "", right = "" },
        component_separators = { left = "·", right = "·" },
      },
      sections = {
        lualine_a = {
          {
            "mode",
            fmt = function(str)
              return str:sub(1, 1)
            end,
          },
        },
        lualine_b = {
          {
            "branch",
            icon = "",
          },
        },
        lualine_c = {
          {
            "filetype",
            icon_only = true,
            separator = "",
            padding = { left = 1, right = 0 },
          },
          {
            "filename",
            path = 3,
            symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" },
          },
          {
            "diagnostics",
            symbols = { error = " ", warn = " ", info = " ", hint = " 󰌵 " },
          },
        },
        lualine_x = {
          {
            "copilot",
            show_colors = true,
            show_loading = true,
          },
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              local names = {}
              for _, client in ipairs(clients) do
                if client.name ~= "copilot" then
                  names[#names + 1] = client.name
                end
              end
              if #names == 0 then
                return ""
              end
              return " " .. table.concat(names, " ")
            end,
          },
          {
            function()
              local reg = vim.fn.reg_recording()
              if reg == "" then
                return ""
              end
              return " @" .. reg
            end,
            color = { fg = "#f38ba8" },
          },
        },
        lualine_y = {
          {
            "progress",
            fmt = function(str)
              return str:gsub("%%%%", "")
            end,
          },
        },
        lualine_z = { "location" },
      },
    },
  },
}
