return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    plugins = {
      marks = true,
      registers = true,
      spelling = { enabled = true, suggestions = 20 },
      presets = {
        operators = true,
        motions   = true,
        text_objects = true,
        windows   = true,
        nav       = true,
        z         = true,
        g         = true,
      },
    },
    win = {
      border = "rounded",  -- none, single, double, shadow
      no_overlap = true,
      padding = { 2, 2, 2, 2 }, -- top, right, bottom, left
      zindex = 1000,
      row = 1,   -- distance from top
      col = 0,   -- distance from left
    },
    layout = {
      height = { min = 4, max = 25 },
      width  = { min = 20, max = 50 },
      spacing = 3,
      align = "left",
    },
    show_help = true,
    show_keys = true,
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    wk.add({
      -- Buffer
      { "<leader>b",  group = "Buffer" },
      { "<leader>bd", "<cmd>bd<cr>",                     desc = "Delete Buffer" },
      { "<leader>bl", "<cmd>ls<cr>",                     desc = "List Buffers" },
      { "<leader>bn", "<cmd>bn<cr>",                     desc = "Next Buffer" },
      { "<leader>bp", "<cmd>bp<cr>",                     desc = "Previous Buffer" },

      -- File
      { "<leader>f",  group = "File" },
      { "<leader>ff", "<cmd>Telescope find_files<cr>",   desc = "Find File" },
      { "<leader>fn", "<cmd>enew<cr>",                   desc = "New File" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>",     desc = "Recent File" },
      { "<leader>fs", "<cmd>w<cr>",                      desc = "Save File" },

      -- Git
      { "<leader>g",  group = "Git" },
      { "<leader>gb", "<cmd>Gitsigns blame_line<cr>",    desc = "Blame Line" },
      { "<leader>gd", "<cmd>Gitsigns diffthis<cr>",      desc = "Diff" },
      { "<leader>gs", "<cmd>Neogit<cr>",                 desc = "Status" },

      -- LSP
      { "<leader>l",  group = "LSP" },
      { "<leader>la", function() vim.lsp.buf.code_action() end, desc = "Code Action" },
      { "<leader>ld", "<cmd>Telescope diagnostics<cr>",          desc = "Diagnostics" },
      { "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format" },
      { "<leader>lr", function() vim.lsp.buf.rename() end,       desc = "Rename" },

      -- Quit / Session
      { "<leader>q",  group = "Quit/Session" },
      { "<leader>qQ", "<cmd>qa!<cr>",                  desc = "Quit All!" },
      { "<leader>qq", "<cmd>q<cr>",                    desc = "Quit" },
      { "<leader>qs", "<cmd>mksession!<cr>",           desc = "Save Session" },
    })
  end,
}

