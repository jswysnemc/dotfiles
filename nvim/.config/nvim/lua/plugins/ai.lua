return {

  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "VeryLazy",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        ["*"] = true,
        -- markdown = true,
        -- help = true,
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)
      require("copilot.command").disable()
    end,
    keys = {
      {
        "<leader>at",
        function()
          if require("copilot.client").is_disabled() then
            require("copilot.command").enable()
          else
            require("copilot.command").disable()
          end
        end,
        desc = "Toggle (Copilot)",
      },
    },
  },

  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "echasnovski/mini.diff",
      "j-hui/fidget.nvim",
    },

    init = function()
      require("utils.codecompanion_fidget_spinner"):init()
    end,

    -- -- stylua: ignore
    -- keys = {
    --   {"<leader>cca", "<CMD>CodeCompanionActions<CR>",     mode = {"n", "v"}, noremap = true, silent = true, desc = "CodeCompanion actions"      },
    --   {"<leader>cci", "<CMD>CodeCompanion<CR>",            mode = {"n", "v"}, noremap = true, silent = true, desc = "CodeCompanion inline"       },
    --   {"<leader>ccc", "<CMD>CodeCompanionChat Toggle<CR>", mode = {"n", "v"}, noremap = true, silent = true, desc = "CodeCompanion chat (toggle)"},
    --   {"<leader>ccp", "<CMD>CodeCompanionChat Add<CR>",    mode = {"v"}     , noremap = true, silent = true, desc = "CodeCompanion chat add code"},
    -- },
    config = function()
      local default_model = "deepseek/deepseek-chat-v3.1:free"
      local available_models = {
        "qwen/qwen3-coder:free",
        "z-ai/glm-4.5-air:free",
        "deepseek/deepseek-r1-0528:free",
        "moonshotai/kimi-k2:free",
        "deepseek/deepseek-chat-v3.1:free",
      }
      local current_model = default_model

      local function select_model()
        vim.ui.select(available_models, {
          prompt = "Select  Model:",
        }, function(choice)
          if choice then
            current_model = choice
            vim.notify("Selected model: " .. current_model)
          end
        end)
      end
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "openrouter",
          },
          inline = {
            adapter = "copilot",
          },
        },
        adapters = {
          http = {

            openrouter = function()
              return require("codecompanion.adapters").extend("openai_compatible", {
                env = {
                  url = "https://openrouter.ai/api",
                  api_key = function()
                    return os.getenv("OPENROUTER_API_KEY")
                  end,
                  chat_url = "/v1/chat/completions",
                },
                schema = {
                  model = {
                    default = current_model,
                  },
                },
              })
            end,
          },
        },
      })
      vim.keymap.set(
        { "n", "v" },
        "<leader>cca",
        "<CMD>CodeCompanionActions<CR>",
        { noremap = true, silent = true, desc = "CodeCompanion actions" }
      )
      vim.keymap.set(
        { "n", "v" },
        "<leader>cci",
        "<CMD>CodeCompanion<CR>",
        { noremap = true, silent = true, desc = "CodeCompanion inline" }
      )
      vim.keymap.set(
        { "n", "v" },
        "<leader>ccc",
        "<CMD>CodeCompanionChat Toggle<CR>",
        { noremap = true, silent = true, desc = "CodeCompanion chat (toggle)" }
      )
      vim.keymap.set(
        "v",
        "<leader>ccp",
        "<CMD>CodeCompanionChat Add<CR>",
        { noremap = true, silent = true, desc = "CodeCompanion chat add code" }
      )
      -- 您需要的新快捷键
      vim.keymap.set(
        "n",
        "<leader>ccs",
        select_model,
        { noremap = true, silent = true, desc = "CodeCompanion select model" }
      )
    end,

    opts = {
      display = {
        diff = {
          enabled = true,
          provider = "mini_diff",
        },
      },

      strategies = {
        chat = { adapter = "copilot" },
        inline = { adapter = "copilot" },
      },

      opts = {
        language = "Chinese", -- "English"|"Chinese"
      },
    },
  },
}
