return {
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason-org/mason.nvim" },
        config = function()
          require("mason-nvim-dap").setup({
            ensure_installed = { "python", "delve", "codelldb", "js" },
            handlers = {
              codelldb = function(config)
                require("mason-nvim-dap").default_setup(config)
              end,
            },
          })
        end,
      },
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
      "theHamsta/nvim-dap-virtual-text",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
      "mxsdev/nvim-dap-vscode-js",
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "󰊄 切换断点" },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("断点条件: "))
        end,
        desc = "󰊄 条件断点",
      },
      { "<leader>dc", function() require("dap").continue() end, desc = "󰝆 开始或继续" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "󰝆 运行到光标处" },
      {
        "<leader>dn",
        function()
          local ft = vim.bo.filetype

          if ft == "python" then
            require("dap-python").test_method()
            return
          end

          if ft == "go" then
            require("dap-go").debug_test()
            return
          end

          vim.notify("当前文件类型不支持最近测试调试", vim.log.levels.WARN)
        end,
        desc = "󰊄 调试最近测试",
      },
      { "<leader>di", function() require("dap").step_into() end, desc = "󰝆 单步进入" },
      { "<leader>do", function() require("dap").step_over() end, desc = "󰝆 单步跳过" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "󰝆 单步跳出" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "󰝆 重新运行上次调试" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "󰋖 打开调试 REPL" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "󰗼 结束调试" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "󰅇 切换调试界面" },
      { "<leader>dx", function() require("dap").clear_breakpoints() end, desc = "󰒍 清除所有断点" },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        desc = "󰊄 查看表达式值",
        mode = { "n", "v" },
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("nvim-dap-virtual-text").setup({})
      dapui.setup({})

      require("dap-python").setup("debugpy-adapter")
      require("dap-go").setup({})
      require("dap-vscode-js").setup({
        debugger_cmd = { "js-debug-adapter" },
        adapters = {
          "pwa-node",
          "pwa-chrome",
          "pwa-msedge",
          "node-terminal",
          "pwa-extensionHost",
        },
      })

      for _, language in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "启动当前文件",
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            console = "integratedTerminal",
            skipFiles = { "<node_internals>/**" },
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "附加到 Node 进程",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            skipFiles = { "<node_internals>/**" },
          },
          {
            type = "pwa-chrome",
            request = "launch",
            name = "启动 Chrome 调试前端",
            url = function()
              return vim.fn.input("调试地址: ", "http://localhost:3000")
            end,
            webRoot = "${workspaceFolder}",
            sourceMaps = true,
            userDataDir = false,
          },
        }
      end

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },
}
