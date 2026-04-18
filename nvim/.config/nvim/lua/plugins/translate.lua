return {
  {
    "uga-rosa/translate.nvim",
    cmd = "Translate",
    opts = {
      default = {
        command = "google",
        output = "floating",
        parse_before = "trim,natural",
        parse_after = "head",
      },
      preset = {
        output = {
          floating = {
            border = "rounded",
            width = 0.6,
          },
        },
      },
    },
    keys = {
      { "<leader>tw", ":Translate zh<CR>", desc = "󰝰 翻译为中文", mode = { "n", "x" } },
      { "<leader>tW", ":Translate zh -output=replace<CR>", desc = "󰝰 翻译并替换", mode = { "n", "x" } },
      { "<leader>te", ":Translate en<CR>", desc = "󰝰 翻译为英文", mode = { "n", "x" } },
    },
  },
}
