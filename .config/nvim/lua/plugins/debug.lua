-- lua/plugins/dap.lua
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "jay-babu/mason-nvim-dap.nvim",
      "williamboman/mason.nvim",
      -- JS/TS adapter layer for vscode-js-debug (optional but recommended)
      "mxsdev/nvim-dap-vscode-js",
    },
    keys = {
      { "<F5>",  function() require("dap").continue() end,              desc = "DAP Continue" },
      { "<F10>", function() require("dap").step_over() end,             desc = "DAP Step Over" },
      { "<F11>", function() require("dap").step_into() end,             desc = "DAP Step Into" },
      { "<F12>", function() require("dap").step_out() end,              desc = "DAP Step Out" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end,desc = "DAP Toggle BP" },
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end, desc = "DAP Conditional BP" },
      { "<leader>du", function() require("dapui").toggle() end,         desc = "DAP UI" },
      { "<leader>dr", function() require("dap").repl.toggle() end,      desc = "DAP REPL" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup({ show_stop_reason = false })

      -- Auto open/close the UI
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Install/bridge DAP adapters via Mason
      require("mason-nvim-dap").setup({
        ensure_installed = {
          "python",   -- debugpy
          "js",       -- vscode-js-debug
          "go",       -- delve
          "codelldb", -- C/C++/Rust
        },
        automatic_installation = true,
      })

      ----------------------------------------------------------------
      -- JS/TS using vscode-js-debug (from mason)
      ----------------------------------------------------------------
      local ok, reg = pcall(require, "mason-registry")
      if ok and reg.has_package("js-debug-adapter") then
        local path = reg.get_package("js-debug-adapter"):get_install_path()
        require("dap-vscode-js").setup({
          debugger_path = path,
          adapters = { "pwa-node", "pwa-chrome", "node-terminal" },
        })
        for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
          dap.configurations[ft] = {
            {
              type = "pwa-node",
              request = "launch",
              name = "Launch file",
              program = "${file}",
              cwd = "${workspaceFolder}",
            },
            {
              type = "pwa-node",
              request = "attach",
              name = "Attach (node --inspect)",
              processId = require("dap.utils").pick_process,
              cwd = "${workspaceFolder}",
            },
            {
              type = "pwa-chrome",
              request = "launch",
              name = "Chrome: http://localhost:3000",
              url = "http://localhost:3000",
              webRoot = "${workspaceFolder}",
            },
          }
        end
      end

      ----------------------------------------------------------------
      -- Python (debugpy)
      ----------------------------------------------------------------
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "Pytest module",
          module = "pytest",
          args = { "-q" },
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
        },
      }

      ----------------------------------------------------------------
      -- Go (delve)
      ----------------------------------------------------------------
      dap.configurations.go = {
        { type = "go", request = "launch", name = "Debug (main)", program = "${workspaceFolder}" },
        { type = "go", request = "launch", name = "Debug file",   program = "${file}" },
        { type = "go", request = "attach", name = "Attach",       processId = require("dap.utils").pick_process },
      }

      ----------------------------------------------------------------
      -- C/C++/Rust (codelldb)
      ----------------------------------------------------------------
      for _, ft in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[ft] = {
          {
            name = "Launch",
            type = "codelldb",
            request = "launch",
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
          {
            name = "Attach process",
            type = "codelldb",
            request = "attach",
            pid = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}

