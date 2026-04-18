local augroup = vim.api.nvim_create_augroup("config", { clear = true })

-- 复制时高亮
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- 打开文件时跳转到上次退出位置
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- 窗口大小变化时自动调整分割
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  command = "wincmd =",
})

-- 在特定窗口中按 q 关闭
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "lspinfo", "man", "notify", "qf", "query" },
  callback = function(args)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = args.buf, silent = true })
  end,
})

-- 文本修改或退出插入模式时自动保存
vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
  group = augroup,
  callback = function()
    if vim.bo.modified and vim.bo.buflisted then
      vim.cmd("silent! update")
    end
  end,
})
