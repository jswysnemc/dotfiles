-- Lua 开发辅助
return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        "lazy.nvim",
      },
    },
  },

  -- Mason: 安装 LSP 服务器
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "[+]",
          package_pending = "[>]",
          package_uninstalled = "[-]",
        },
      },
    },
  },

  -- 桥接: mason -> lspconfig
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "lua_ls",
        "gopls",
        "rust_analyzer",
        "pyright",
        "ts_ls",
        "clangd",
        "html",
        "cssls",
        "jsonls",
        "bashls",
      },
      automatic_enable = true,
    },
  },

  -- LSP 配置 (Neovim 0.12 原生 API)
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-org/mason-lspconfig.nvim" },
    config = function()
      -- 服务器专属配置
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            completion = { callSnippet = "Replace" },
          },
        },
      })

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            cargo = { allFeatures = true },
          },
        },
      })

      -- LSP 挂载时设置 buffer 快捷键
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp", { clear = true }),
        callback = function(args)
          local buf = args.buf
          local opts = { buffer = buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "󰊄 跳转到定义" }))
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "󰊄 跳转到声明" }))
          vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "󰊄 查看引用" }))
          vim.keymap.set("n", "gI", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "󰊄 跳转到实现" }))
          vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, vim.tbl_extend("force", opts, { desc = "󰊄 跳转到类型定义" }))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "󰋖 悬停文档" }))
          vim.keymap.set("n", "gK", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "󰊄 签名帮助" }))
          vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, vim.tbl_extend("force", opts, { desc = "󰊄 运行 CodeLens" }))
          vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "󰑕 重命名" }))
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "󰊄 代码操作" }))
        end,
      })

      -- 诊断配置
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "-" },
        float = { border = "rounded", source = "if_many" },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "E",
            [vim.diagnostic.severity.WARN] = "W",
            [vim.diagnostic.severity.INFO] = "I",
            [vim.diagnostic.severity.HINT] = "H",
          },
        },
        underline = true,
        update_in_insert = false,
      })
    end,
  },
}
