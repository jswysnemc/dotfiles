return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      provider = "wishub",
      input = {
        provider = "snacks",
      },
      selector = {
        provider = "fzf_lua",
      },
      mode = "agentic",
      providers = {
        wishub = {
          __inherited_from = "openai",
          endpoint = "https://wishub-x6.ctyun.cn/coding/v1",
          model = "GLM-5.1",
          api_key_name = "WISHUB_API_KEY",
          timeout = 30000,
          extra_request_body = {
            temperature = 0.75,
            max_tokens = 20480,
          },
        },
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-sonnet-4-20250514",
          timeout = 30000,
          extra_request_body = {
            temperature = 0.75,
            max_tokens = 20480,
          },
        },
      },
      behaviour = {
        auto_suggestions = false,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
        minimize_diff = true,
        auto_add_current_file = true,
      },
      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        toggle = {
          default = "<leader>at",
          debug = "<leader>ad",
          hint = "<leader>ah",
          suggestion = "<leader>as",
        },
      },
    },
    keys = function(_, keys)
      local opts =
        require("lazy.core.plugin").values(require("lazy.core.config").spec.plugins["avante.nvim"], "opts", false)
      local mappings = {
        {
          opts.mappings.ask,
          function() require("avante.api").ask() end,
          desc = "󰊕 AI 助手：提问",
          mode = { "n", "v" },
        },
        {
          opts.mappings.refresh,
          function() require("avante.api").refresh() end,
          desc = "󰊕 AI 助手：刷新",
          mode = "v",
        },
        {
          opts.mappings.edit,
          function() require("avante.api").edit() end,
          desc = "󰊕 AI 助手：编辑",
          mode = { "n", "v" },
        },
      }
      mappings = vim.tbl_filter(function(m) return m[1] and #m[1] > 0 end, mappings)
      return vim.list_extend(mappings, keys)
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "ibhagwan/fzf-lua",
      "nvim-mini/mini.pick",
      {
        "stevearc/dressing.nvim",
        opts = {
          select = { enabled = false },
          input = { enabled = false },
        },
      },
      "folke/snacks.nvim",
      "echasnovski/mini.icons",
      "HakonHarnes/img-clip.nvim",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    lazy = false,
    cmd = "Copilot",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 30,
        hide_during_completion = false,
        trigger_on_accept = true,
        keymap = {
          accept = "<C-l>",
          dismiss = "<C-]>",
          next = "<M-]>",
          prev = "<M-[>",
        },
      },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = false,
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)
      vim.keymap.set("n", "<leader>tc", function()
        local client = require("copilot.client")
        if client.is_disabled() then
          vim.cmd("Copilot enable")
        else
          vim.cmd("Copilot disable")
        end
      end, { desc = " 切换 Copilot" })
    end,
  },
}
