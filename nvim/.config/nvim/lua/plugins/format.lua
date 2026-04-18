return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
      formatters_by_ft = {
        lua = { "stylua" },
        go = { "gofmt", "goimports" },
        python = { "ruff_format" },
        rust = { "rustfmt" },
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescriptreact = { "prettierd" },
        vue = { "prettierd" },
        css = { "prettierd" },
        html = { "prettierd" },
        json = { "prettierd" },
        yaml = { "prettierd" },
        markdown = { "prettierd" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
      },
      formatters = {
        shfmt = {
          prepend_args = { "-i", "4", "-bn", "-ci", "-sr" },
        },
        ["clang-format"] = {
          prepend_args = { "--style={IndentWidth: 4, TabWidth: 4, UseTab: Never}" },
        },
      },
    },
    keys = {
      { "<leader>cf", function() require("conform").format({ lsp_fallback = true }) end, desc = "󰒉 格式化代码", mode = { "n", "v" } },
      { "<leader>tf", function() vim.b.disable_autoformat = not vim.b.disable_autoformat end, desc = "󰒉 切换自动格式化" },
    },
    config = function(_, opts)
      require("conform").setup(opts)
      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, { desc = "󰒉 禁用自动格式化", bang = true })
      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = "󰒉 启用自动格式化" })
    end,
  },
}
