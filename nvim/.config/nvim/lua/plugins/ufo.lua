return {
  {
    "kevinhwang91/nvim-ufo",
    event = "VeryLazy",
    dependencies = { "kevinhwang91/promise-async" },
    opts = {
      open_fold_hl_timeout = 150,
      provider_selector = function(_, filetype, _)
        return { "treesitter", "indent" }
      end,
      close_fold_kinds_for_ft = {
        default = { "imports", "comment" },
      },
      preview = {
        win_config = {
          border = "rounded",
          winblend = 0,
        },
      },
    },
    init = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    keys = {
      { "zR", function() require("ufo").openAllFolds() end, desc = "󰢬 打开所有折叠" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "󰢬 关闭所有折叠" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end, desc = "󰢬 打开部分折叠" },
      { "zm", function() require("ufo").closeFoldsWith() end, desc = "󰢬 关闭部分折叠" },
      { "K", function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then vim.lsp.buf.hover() end
      end, desc = "󰢬 预览折叠 / 悬浮文档" },
    },
  },
}
