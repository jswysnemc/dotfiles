return {
  {
    "nvim-pack/nvim-spectre",
    cmd = { "Spectre" },
    opts = {
      default = {
        find = { cmd = "rg" },
        replace = { cmd = "sed" },
      },
      is_insert_mode = true,
    },
    keys = {
      { "<leader>sr", "<cmd>Spectre<cr>", desc = "󰘤 全局搜索替换" },
      { "<leader>sw", "<cmd>Spectre<cr>", desc = "󰘤 全局搜索替换（当前词）", mode = "v" },
    },
  },
}
