-- lua/plugins/lsp.lua
return {
    {
        "williamboman/mason.nvim",
        build = ":MasonUpdate",
        cmd = "Mason",
        keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason: Manager" } },
        opts = { ui = { border = "rounded" } },
    },

    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "neovim/nvim-lspconfig", "williamboman/mason.nvim" },
        event = { "BufReadPre", "BufNewFile" },
        opts = function()
            -- Pick correct TS server name for your lspconfig version
            return {
                ensure_installed = {
                    "lua_ls",
                    "ts_ls",
                    "pyright",
                    "gopls",
                    "rust_analyzer",
                    "html",
                    "cssls",
                    "jsonls",
                    "yamlls",
                    "bashls",
                    "dockerls",
                    "cmake",
                },
                automatic_installation = true,
            }
        end,
    },

    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            local lspconfig = require("lspconfig")

            local capabilities = vim.lsp.protocol.make_client_capabilities()
            pcall(function()
                capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
            end)

            -- signs
            for type, icon in pairs({ Error = " ", Warn = " ", Hint = " ", Info = " " }) do
                local hl = "DiagnosticSign" .. type
                vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
            end

            -- on_attach
            local function on_attach(_, bufnr)
                local map = function(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end
                map("n", "gd", vim.lsp.buf.definition, "Go to definition")
                map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
                map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
                map("n", "gr", vim.lsp.buf.references, "References")
                map("n", "K", vim.lsp.buf.hover, "Hover")
                map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
                map({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, "Code action")
                map("n", "<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
                map("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
                map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
                map("n", "<leader>lf", function() vim.lsp.buf.format({ async = false }) end, "Format buffer")
            end

            -- server-specific opts
            local servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            workspace = { checkThirdParty = false },
                            diagnostics = { globals = { "vim" } },
                            format = { enable = false },
                        },
                    },
                },
                tsserver = {}, -- old name; we’ll alias below if needed
                ts_ls = {},    -- new name
                pyright = {},
                gopls = {},
                rust_analyzer = {},
                html = {},
                cssls = {},
                jsonls = {},
                yamlls = {},
                bashls = {},
                dockerls = {},
                cmake = {},
            }

            -- Use mason-lspconfig if available
            local ok_mlsp, mlsp = pcall(require, "mason-lspconfig")
            if ok_mlsp then
                -- Make sure mason-lspconfig itself is set up (in case opts didn’t run yet)
                pcall(mlsp.setup)

                -- Prefer setup_handlers if present; otherwise fallback to manual loop
                if type(mlsp.setup_handlers) == "function" then
                    mlsp.setup_handlers({
                        function(server_name)
                            local opts = servers[server_name] or {}
                            opts.capabilities = capabilities
                            local prev = opts.on_attach
                            opts.on_attach = function(client, bufnr)
                                if prev then pcall(prev, client, bufnr) end
                                on_attach(client, bufnr)
                            end
                            lspconfig[server_name].setup(opts)
                        end,
                    })
                else
                    -- Fallback: iterate over installed servers
                    for _, server_name in ipairs(mlsp.get_installed_servers()) do
                        local opts = servers[server_name] or {}
                        opts.capabilities = capabilities
                        local prev = opts.on_attach
                        opts.on_attach = function(client, bufnr)
                            if prev then pcall(prev, client, bufnr) end
                            on_attach(client, bufnr)
                        end
                        lspconfig[server_name].setup(opts)
                    end
                end
            else
                -- Final fallback: set up the common servers directly
                for name, opts in pairs(servers) do
                    if lspconfig[name] then
                        opts.capabilities = capabilities
                        local prev = opts.on_attach
                        opts.on_attach = function(client, bufnr)
                            if prev then pcall(prev, client, bufnr) end
                            on_attach(client, bufnr)
                        end
                        lspconfig[name].setup(opts)
                    end
                end
            end

            vim.diagnostic.config({
                virtual_text = { spacing = 2, prefix = "●" },
                severity_sort = true,
                float = { border = "rounded" },
            })
        end,
    },
}
