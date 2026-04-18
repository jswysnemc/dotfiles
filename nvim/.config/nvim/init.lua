-- Leader 键（必须在 lazy.nvim 加载前设置）
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- 引导安装 lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 加载核心配置
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- 配置 lazy.nvim 插件管理器
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = {
    colorscheme = { "catppuccin" },
  },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      -- 禁用内置插件以加速启动
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
