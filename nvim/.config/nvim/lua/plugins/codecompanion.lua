return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionCmd", "CodeCompanionAction" },
    keys = {
      { "<leader>ca", "<cmd>CodeCompanionAction<cr>", desc = "󰊕 AI 操作" },
      { "<leader>cc", "<cmd>CodeCompanionChat<cr>", desc = "󰊕 AI 对话" },
      { "<leader>ci", "<cmd>CodeCompanion<cr>", desc = "󰊕 AI 内联", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        acp = {
          claude_code_anthropic = function()
            return require("codecompanion.adapters.claude_code_anthropic")
          end,
        },
      },
      strategies = {
        chat = { adapter = "claude_code_anthropic" },
        inline = { adapter = "claude_code_anthropic" },
      },
    },
  },
}
