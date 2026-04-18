-- 基础设置
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.clipboard = "unnamedplus"
vim.opt.cursorline = true

-- 缩进
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.wrap = false

-- 搜索
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- 编辑器
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.inccommand = "split"
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.pumheight = 10
vim.opt.wildmode = "longest:full,full"
vim.opt.undofile = true
vim.opt.list = true
vim.opt.listchars = { tab = "  ", trail = "-", nbsp = "+" }

-- 窗口分割
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.laststatus = 3
vim.opt.showtabline = 2

-- 折叠（基于 Treesitter）
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99

-- 外观
vim.opt.termguicolors = true
vim.opt.fillchars = { foldopen = "▾", foldclose = "▸", fold = " ", foldsep = " ", diff = "╱", msgsep = "─" }
