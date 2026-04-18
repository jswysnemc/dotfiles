-- 窗口导航
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "󰅇 左侧窗口" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "󰅇 下方窗口" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "󰅇 上方窗口" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "󰅇 右侧窗口" })

-- 缓冲区 切换
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "󰉋 上一个 缓冲区" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "󰉋 下一个 缓冲区" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "󰉋 上一个 缓冲区" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "󰉋 下一个 缓冲区" })

-- 清除搜索高亮
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "󰒍 清除搜索高亮" })

-- 调整窗口大小
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "󰆽 增加窗口高度" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "󰆽 减小窗口高度" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "󰆽 减小窗口宽度" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "󰆽 增加窗口宽度" })

-- 移动行
vim.keymap.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "󰝆 下移一行" })
vim.keymap.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "󰝆 上移一行" })
vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "󰝆 下移选区" })
vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "󰝆 上移选区" })

-- 分屏
vim.keymap.set("n", "<leader>-", "<C-w>s", { desc = "󰅇 水平分屏" })
vim.keymap.set("n", "<leader>|", "<C-w>v", { desc = "󰅇 垂直分屏" })

-- 界面
vim.keymap.set("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "󰖶 切换自动换行" })

-- 退出
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "󰗼 全部退出" })

-- LSP
vim.keymap.set("n", "<leader>cr", function() return ":IncRename " .. vim.fn.expand("<cword>") end, { expr = true, desc = "󰑕 重命名符号" })
