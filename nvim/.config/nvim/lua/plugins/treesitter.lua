return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- 安装解析器
      local install = require("nvim-treesitter.install")
      install.prefer_git = false

      local languages = {
        "bash",
        "c",
        "cpp",
        "css",
        "diff",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "html",
        "java",
        "javascript",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "scss",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "vue",
        "yaml",
      }

      local config = require("nvim-treesitter.config")
      local installed = config.get_installed()
      local to_install = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, languages)

      if #to_install > 0 then
        install.install(to_install)
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    config = function()
      local textobjects = require("nvim-treesitter-textobjects")
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

      textobjects.setup({
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      })

      -- 选择文本对象
      vim.keymap.set({ "o", "x" }, "af", function() select.select_textobject("@function.outer") end, { desc = "󰊄 选择外部函数" })
      vim.keymap.set({ "o", "x" }, "if", function() select.select_textobject("@function.inner") end, { desc = "󰊄 选择内部函数" })
      vim.keymap.set({ "o", "x" }, "ac", function() select.select_textobject("@class.outer") end, { desc = "󰊄 选择外部类" })
      vim.keymap.set({ "o", "x" }, "ic", function() select.select_textobject("@class.inner") end, { desc = "󰊄 选择内部类" })
      vim.keymap.set({ "o", "x" }, "ia", function() select.select_textobject("@parameter.inner") end, { desc = "󰊄 选择内部参数" })
      vim.keymap.set({ "o", "x" }, "aa", function() select.select_textobject("@parameter.outer") end, { desc = "󰊄 选择外部参数" })

      -- 在文本对象间跳转
      vim.keymap.set("n", "]f", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "󰝆 下一个函数开始" })
      vim.keymap.set("n", "]c", function() move.goto_next_start("@class.outer", "textobjects") end, { desc = "󰝆 下一个类开始" })
      vim.keymap.set("n", "[f", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "󰝆 上一个函数开始" })
      vim.keymap.set("n", "[c", function() move.goto_previous_start("@class.outer", "textobjects") end, { desc = "󰝆 上一个类开始" })
      vim.keymap.set("n", "]F", function() move.goto_next_end("@function.outer", "textobjects") end, { desc = "󰝆 下一个函数结束" })
      vim.keymap.set("n", "]C", function() move.goto_next_end("@class.outer", "textobjects") end, { desc = "󰝆 下一个类结束" })
      vim.keymap.set("n", "[F", function() move.goto_previous_end("@function.outer", "textobjects") end, { desc = "󰝆 上一个函数结束" })
      vim.keymap.set("n", "[C", function() move.goto_previous_end("@class.outer", "textobjects") end, { desc = "󰝆 上一个类结束" })
    end,
  },
}
