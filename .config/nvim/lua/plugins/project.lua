return {
    -- Project detection & switching
    {
        "ahmedkhalf/project.nvim",
        event = "VeryLazy",
        config = function()
            require("project_nvim").setup({
                -- Try LSP first, then fallback to patterns
                detection_methods = { "lsp", "pattern" },
                patterns = {
                    ".git",
                    "package.json",
                    "pyproject.toml",
                    "poetry.lock",
                    "requirements.txt",
                    "Cargo.toml",
                    "go.mod",
                    "Makefile",
                    "CMakeLists.txt",
                    "gradlew",
                    "pom.xml",
                },
                -- Change directory automatically
                manual_mode = false,
                silent_chdir = true,
            })
            -- Telescope integration (make sure you have telescope installed)
            pcall(function() require("telescope").load_extension("projects") end)

            -- Keymaps (project switching)
            vim.keymap.set("n", "<leader>pp", "<cmd>Telescope projects<CR>", { desc = "Projects: Switch/Open" })
        end,
    },

    -- Task runner (build / run / test) with language templates
    {
        "stevearc/overseer.nvim",
        cmd = {
            "OverseerRun", "OverseerToggle", "OverseerQuickAction",
            "OverseerLoadBundle", "OverseerSaveBundle", "OverseerClearCache",
        },
        keys = {
            { "<leader>or", "<cmd>OverseerRun<CR>",         desc = "Overseer: Run task" },
            { "<leader>oo", "<cmd>OverseerToggle<CR>",      desc = "Overseer: Toggle UI" },
            { "<leader>ob", desc = "Overseer: Build (auto)" },
            { "<leader>ot", desc = "Overseer: Test (auto)" },
            { "<leader>os", desc = "Overseer: Run (auto)" },
        },
        config = function()
            local ok_toggleterm = pcall(require, "toggleterm.terminal")
            local default_strategy = ok_toggleterm and { "toggleterm", direction = "float" } or { "terminal" }

            require("overseer").setup({
                strategy = default_strategy,
                templates = { "builtin" }, -- include built-ins, we also register more below
                task_list = {
                    direction = "left",
                    min_width = 40,
                    bindings = {
                        ["q"] = function() require("overseer").close() end,
                    },
                },
            })

            local overseer = require("overseer")

            -----------------------------------------------------------------------
            -- Helpers
            -----------------------------------------------------------------------
            local function exists(path)
                return vim.loop.fs_stat(path) ~= nil
            end

            local function in_root(files)
                for _, f in ipairs(files) do
                    if exists(f) then return true end
                end
                return false
            end

            local function tmpl(opts)
                -- Convenience to build a simple task template
                return {
                    name = opts.name,
                    desc = opts.desc,
                    priority = opts.priority or 50,
                    condition = opts.condition, -- { filetype=..., dir=... } OR function()
                    builder = function()
                        return {
                            cmd = opts.cmd,
                            args = opts.args or {},
                            cwd = opts.cwd or vim.loop.cwd(),
                            components = opts.components or { "default" },
                            env = opts.env,
                            strategy = opts.strategy or default_strategy,
                        }
                    end,
                }
            end

            -----------------------------------------------------------------------
            -- Language / tool templates
            -----------------------------------------------------------------------

            -- JavaScript / TypeScript (npm / pnpm / yarn)
            local function js_pm()
                if exists("pnpm-lock.yaml") then return "pnpm" end
                if exists("yarn.lock") then return "yarn" end
                return "npm"
            end

            overseer.register_template(tmpl({
                name = "JS: Install deps",
                desc = "Install dependencies (npm/pnpm/yarn)",
                condition = function() return in_root({ "package.json" }) end,
                cmd = js_pm(),
                args = { "install" },
            }))

            overseer.register_template(tmpl({
                name = "JS: Dev server",
                desc = "Run dev server (npm run dev)",
                condition = function() return in_root({ "package.json" }) end,
                cmd = js_pm(),
                args = { "run", "dev" },
            }))

            overseer.register_template(tmpl({
                name = "JS: Build",
                desc = "Build (npm run build)",
                condition = function() return in_root({ "package.json" }) end,
                cmd = js_pm(),
                args = { "run", "build" },
            }))

            overseer.register_template(tmpl({
                name = "JS: Test",
                desc = "Test (npm test / vitest / jest)",
                condition = function() return in_root({ "package.json" }) end,
                cmd = js_pm(),
                args = { "test" },
            }))

            -- Python (uv/poetry/pip) + pytest
            local function py_exe()
                -- Prefer venv if present
                local venv = vim.fn.getenv("VIRTUAL_ENV")
                if venv and #venv > 0 then
                    local exe = venv .. "/bin/python"
                    if exists(exe) then return exe end
                end
                -- uv or python fallback
                if vim.fn.executable("uv") == 1 then return "uv" end
                return "python"
            end

            overseer.register_template(tmpl({
                name = "Python: Run file",
                desc = "python <current file>",
                condition = { filetype = { "python" } },
                builder = function()
                    local file = vim.fn.expand("%:p")
                    local exe = py_exe()
                    local cmd, args
                    if exe == "uv" then
                        cmd, args = "uv", { "run", "python", file }
                    else
                        cmd, args = exe, { file }
                    end
                    return {
                        cmd = cmd,
                        args = args,
                        components = { "default" },
                        strategy = default_strategy,
                    }
                end,
            }))

            overseer.register_template(tmpl({
                name = "Python: Pytest",
                desc = "pytest -q",
                condition = function()
                    return in_root({ "pytest.ini", "pyproject.toml", "requirements.txt" })
                        or vim.fn.glob("tests") ~= ""
                end,
                cmd = (vim.fn.executable("uv") == 1) and "uv" or "pytest",
                args = (vim.fn.executable("uv") == 1) and { "run", "pytest", "-q" } or { "-q" },
            }))

            -- Go
            overseer.register_template(tmpl({
                name = "Go: Run",
                desc = "go run .",
                condition = function() return in_root({ "go.mod" }) end,
                cmd = "go",
                args = { "run", "." },
            }))
            overseer.register_template(tmpl({
                name = "Go: Build",
                desc = "go build ./...",
                condition = function() return in_root({ "go.mod" }) end,
                cmd = "go",
                args = { "build", "./..." },
            }))
            overseer.register_template(tmpl({
                name = "Go: Test",
                desc = "go test ./...",
                condition = function() return in_root({ "go.mod" }) end,
                cmd = "go",
                args = { "test", "./..." },
            }))

            -- Rust
            overseer.register_template(tmpl({
                name = "Rust: Build",
                desc = "cargo build",
                condition = function() return in_root({ "Cargo.toml" }) end,
                cmd = "cargo",
                args = { "build" },
            }))
            overseer.register_template(tmpl({
                name = "Rust: Run",
                desc = "cargo run",
                condition = function() return in_root({ "Cargo.toml" }) end,
                cmd = "cargo",
                args = { "run" },
            }))
            overseer.register_template(tmpl({
                name = "Rust: Test",
                desc = "cargo test",
                condition = function() return in_root({ "Cargo.toml" }) end,
                cmd = "cargo",
                args = { "test" },
            }))

            -- C / C++ (CMake / Make)
            overseer.register_template(tmpl({
                name = "CMake: Configure (build/)",
                desc = "cmake -S . -B build",
                condition = function() return in_root({ "CMakeLists.txt" }) end,
                cmd = "cmake",
                args = { "-S", ".", "-B", "build" },
            }))
            overseer.register_template(tmpl({
                name = "CMake: Build",
                desc = "cmake --build build -j",
                condition = function() return in_root({ "CMakeLists.txt" }) end,
                cmd = "cmake",
                args = { "--build", "build", "-j" },
            }))
            overseer.register_template(tmpl({
                name = "Make: Build",
                desc = "make",
                condition = function() return in_root({ "Makefile" }) end,
                cmd = "make",
            }))

            -- Java (Gradle / Maven)
            overseer.register_template(tmpl({
                name = "Gradle: Build",
                desc = "./gradlew build",
                condition = function() return in_root({ "gradlew" }) end,
                cmd = (vim.fn.has("win32") == 1) and "gradlew.bat" or "./gradlew",
                args = { "build" },
            }))
            overseer.register_template(tmpl({
                name = "Maven: Package",
                desc = "mvn -q -DskipTests package",
                condition = function() return in_root({ "pom.xml" }) end,
                cmd = "mvn",
                args = { "-q", "-DskipTests", "package" },
            }))

            -- Generic test runner if `justfile` exists
            if vim.fn.executable("just") == 1 then
                overseer.register_template(tmpl({
                    name = "just: default",
                    desc = "Run `just`",
                    condition = function() return in_root({ "justfile", "Justfile" }) end,
                    cmd = "just",
                }))
            end

            -----------------------------------------------------------------------
            -- “Smart” helpers: one-key build/test/run (auto-pick best template)
            -----------------------------------------------------------------------
            local function pick_and_run(kind)
                -- `kind` is "build" | "test" | "run"
                local candidates = {
                    build = { "CMake: Build", "Make: Build", "Gradle: Build", "Maven: Package", "Rust: Build", "Go: Build", "JS: Build" },
                    test  = { "Python: Pytest", "Rust: Test", "Go: Test", "JS: Test" },
                    run   = { "JS: Dev server", "Rust: Run", "Go: Run", "Python: Run file" },
                }
                local wanted = candidates[kind] or {}

                local tasks = require("overseer.task_list").list_tasks()
                -- ensure we always re-create, so we pick up cwd changes
                for _, name in ipairs(wanted) do
                    if name:match("JS: ") and not in_root({ "package.json" }) then goto continue end
                    if name:match("Python") and vim.bo.filetype ~= "python" and not in_root({ "pytest.ini", "pyproject.toml", "requirements.txt" }) then goto continue end
                    -- run the first matching template name
                    local ok = overseer.run_template({ name = name })
                    if ok then return end
                    ::continue::
                end
                -- Fallback: open task picker
                vim.cmd("OverseerRun")
            end

            vim.keymap.set("n", "<leader>ob", function() pick_and_run("build") end, { desc = "Overseer: Build (auto)" })
            vim.keymap.set("n", "<leader>ot", function() pick_and_run("test") end, { desc = "Overseer: Test (auto)" })
            vim.keymap.set("n", "<leader>os", function() pick_and_run("run") end, { desc = "Overseer: Run (auto)" })
        end,
    },


    ---------------------------------------------------------------------------
    -- Cookiecutter integration
    ---------------------------------------------------------------------------
    {
        "nvim-lua/plenary.nvim", -- gives us vim.system()
        config = function()
            -- helper: run cookiecutter and then cd into project
            local function project_new(template)
                vim.ui.input({ prompt = "Cookiecutter template (path or repo): ", default = template or "" },
                    function(input)
                        if not input or input == "" then return end
                        -- run cookiecutter
                        vim.notify("Creating project from " .. input .. " …", vim.log.levels.INFO)
                        vim.system({ "cookiecutter", input }, { text = true }, function(res)
                            if res.code ~= 0 then
                                vim.schedule(function()
                                    vim.notify("cookiecutter failed:\n" .. res.stderr, vim.log.levels.ERROR)
                                end)
                                return
                            end
                            -- cookiecutter prints the project dir path on stdout’s last line
                            local lines = vim.split(res.stdout, "\n", { trimempty = true })
                            local target = lines[#lines]
                            if not target or target == "" then
                                -- fallback: ask the user
                                target = vim.fn.input("New project path: ", "", "dir")
                            end
                            if target and target ~= "" then
                                vim.schedule(function()
                                    vim.cmd("cd " .. vim.fn.fnameescape(target))
                                    -- open README or telescope
                                    local readme = target .. "/README.md"
                                    if vim.loop.fs_stat(readme) then
                                        vim.cmd("edit " .. vim.fn.fnameescape(readme))
                                    else
                                        vim.cmd("Telescope find_files")
                                    end
                                    vim.notify("Project ready at " .. target, vim.log.levels.INFO)
                                end)
                            end
                        end)
                    end)
            end

            -- user command + keymap
            vim.api.nvim_create_user_command("ProjectNew", function(opts) project_new(opts.args) end, { nargs = "?" })
            vim.keymap.set("n", "<leader>pN", "<cmd>ProjectNew<CR>", { desc = "Projects: New (Cookiecutter)" })
        end,
    },
}
