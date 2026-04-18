return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "ruff" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        dockerfile = { "hadolint" },
        yaml = { "yamllint" },
      }

      local augroup = vim.api.nvim_create_augroup("lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = augroup,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
    keys = {
      { "<leader>xl", function() require("lint").try_lint() end, desc = "󰏢 触发 Lint" },
    },
  },
}
