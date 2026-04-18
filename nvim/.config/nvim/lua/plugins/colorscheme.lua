return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "mocha",
      background = { light = "latte", dark = "mocha" },
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = { enabled = false },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      integrations = {
        gitsigns = true,
        blink_cmp = true,
        mini = { enabled = true },
        fzf = true,
        oil = true,
        mason = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
        treesitter = true,
        which_key = true,
        snacks = { enabled = true },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")

      -- 强制所有浮窗和侧栏透明
      local groups = {
        "NormalFloat", "FloatBorder", "FloatTitle",
        "NormalNC", "NormalSB",
        "WhichKeyNormal", "WhichKeyBorder", "WhichKeyFloat",
        "FzfLuaNormal", "FzfLuaBorder", "FzfLuaPreviewNormal", "FzfLuaPreviewBorder",
        "NoicePopup", "NoicePopupBorder",
        "BlinkCmpMenu", "BlinkCmpMenuBorder", "BlinkCmpDoc", "BlinkCmpDocBorder",
        "LspFloatWinNormal", "LspFloatWinBorder",
        "SnacksDashboardNormal",
      }
      for _, group in ipairs(groups) do
        vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
      end
    end,
  },
}
