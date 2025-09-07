-- lua/wal_profiles.lua
local M         = {}

-- ───────── Locations ─────────
local WAL_CACHE = vim.fn.expand("~/.cache/wal")
local PROFILES  = vim.fn.expand("~/.local/share/wal-profiles")
local CURRENT   = PROFILES .. "/.current"

-- ───────── Defaults (override via M.setup{ ... }) ─────────
M.opts          = {
    min_l_bg       = 0.38,
    lift_bg        = 0.08,
    satm_bg        = 0.95,

    lift_fg        = 0.10,
    satm_fg        = 1.00,

    lift_cols      = 0.30,
    satm_cols      = 0.95,

    force_alpha_bg = nil,  -- e.g. "#1e1e1e"
    autoload       = true, -- load last profile on startup
}

local function read_current_name()
    if vim.fn.filereadable(CURRENT) == 1 then
        local name = (vim.fn.readfile(CURRENT)[1] or ""):gsub("%s+$", "")
        if name ~= "" then return name end
    end
    return nil
end


-- ───────── FS utils ─────────
local function ensure_dir(path)
    if vim.fn.isdirectory(path) == 0 then vim.fn.mkdir(path, "p") end
end

local function copy_if_exists(src, dst_dir)
    if vim.fn.filereadable(src) == 1 then
        vim.fn.writefile(vim.fn.readfile(src), dst_dir .. "/" .. vim.fn.fnamemodify(src, ":t"))
    end
end

local function list_profiles()
    ensure_dir(PROFILES)
    local entries = {}
    for _, p in ipairs(vim.fn.glob(PROFILES .. "/*", 1, 1)) do
        if vim.fn.isdirectory(p) == 1 then table.insert(entries, vim.fn.fnamemodify(p, ":t")) end
    end
    table.sort(entries)
    return entries
end

-- ───────── Color math (HSL) ─────────
-- Reads a wal profile dir and populates vim.g.color0..15 + background/foreground
local function load_palette_from_dir(dir)
    -- Try colors.json first (preferred; contains "colors" and "special")
    local json = dir .. "/colors.json"
    if vim.fn.filereadable(json) == 1 then
        local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(json), "\n"))
        if ok and data then
            -- standard pywal layout: data.colors.color0..color15 + data.special.background/foreground
            if type(data.colors) == "table" then
                for k, v in pairs(data.colors) do
                    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then
                        vim.g[k] = v -- k e.g. "color0"
                    end
                end
            end
            if type(data.special) == "table" then
                if type(data.special.background) == "string" then vim.g.background = data.special.background end
                if type(data.special.foreground) == "string" then vim.g.foreground = data.special.foreground end
            end
            -- Fallbacks if special missing
            vim.g.background = vim.g.background or vim.g.color0
            vim.g.foreground = vim.g.foreground or vim.g.color7 or vim.g.color15
            return true
        end
    end

    -- Fallback: plain "colors" file (16 lines, color0..color15)
    local plain = dir .. "/colors"
    if vim.fn.filereadable(plain) == 1 then
        local lines = vim.fn.readfile(plain)
        for i = 1, math.min(16, #lines) do
            local hex = lines[i]
            if hex and hex:match("^#%x%x%x%x%x%x$") then
                vim.g["color" .. (i - 1)] = hex
            end
        end
        vim.g.background = vim.g.background or vim.g.color0
        vim.g.foreground = vim.g.foreground or vim.g.color7 or vim.g.color15
        return true
    end

    return false
end

-- Read the CURRENT pywal cache (~/.cache/wal) into a palette table
local function read_wal_cache_palette()
    local json = WAL_CACHE .. "/colors.json"
    if vim.fn.filereadable(json) == 1 then
        local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(json), "\n"))
        if ok and data then
            local pal = { colors = {}, special = {} }
            if type(data.colors) == "table" then
                for k, v in pairs(data.colors) do
                    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then
                        pal.colors[k] = v
                    end
                end
            end
            if type(data.special) == "table" then
                pal.special.background = data.special.background
                pal.special.foreground = data.special.foreground
            end
            pal.special.background = pal.special.background or pal.colors.color0 or "#000000"
            pal.special.foreground = pal.special.foreground or pal.colors.color7 or pal.colors.color15 or "#ffffff"
            return pal
        end
    end

    -- fallback: 16-line plain file
    local plain = WAL_CACHE .. "/colors"
    if vim.fn.filereadable(plain) == 1 then
        local lines = vim.fn.readfile(plain)
        local pal = { colors = {}, special = {} }
        for i = 1, math.min(16, #lines) do
            local hex = lines[i]
            if hex and hex:match("^#%x%x%x%x%x%x$") then
                pal.colors["color" .. (i - 1)] = hex
            end
        end
        pal.special.background = pal.colors.color0 or "#000000"
        pal.special.foreground = pal.colors.color7 or pal.colors.color15 or "#ffffff"
        return pal
    end

    return nil
end


local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function hex_to_rgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7),
        16)
end
local function rgb_to_hex(r, g, b) return string.format("#%02X%02X%02X", r, g, b) end
local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, l = 0, 0, (max + min) / 2
    if max ~= min then
        local d = max - min
        s = l > 0.5 and d / (2 - max - min) or d / (max + min)
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, l
end
local function hsl_to_rgb(h, s, l)
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end; if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    if s == 0 then
        local v = math.floor(l * 255 + 0.5); return v, v, v
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    local r = hue2rgb(p, q, h + 1 / 3)
    local g = hue2rgb(p, q, h)
    local b = hue2rgb(p, q, h - 1 / 3)
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end
local function brighten_hsl(hex, l_add, s_mult)
    if not hex or #hex < 7 then return hex end
    local r, g, b = hex_to_rgb(hex); local h, s, l = rgb_to_hsl(r, g, b)
    l = clamp(l + (l_add or 0), 0, 1); s = clamp(s * (s_mult or 1), 0, 1)
    local rr, gg, bb = hsl_to_rgb(h, s, l); return rgb_to_hex(rr, gg, bb)
end
local function set_min_lightness(hex, minL, s_mult, extra_lift)
    if not hex or #hex < 7 then return hex end
    local r, g, b = hex_to_rgb(hex); local h, s, l = rgb_to_hsl(r, g, b)
    l = math.max(l, minL or 0.35); s = clamp(s * (s_mult or 1), 0, 1)
    l = clamp(l + (extra_lift or 0), 0, 1)
    local rr, gg, bb = hsl_to_rgb(h, s, l); return rgb_to_hex(rr, gg, bb)
end

-- ───────── Palette helpers ─────────
local function wal_base_bg() return vim.g.color0 or "#0f0f0f" end
local function wal_base_fg() return vim.g.color15 or "#e6e6e6" end

-- Public: bright logo colors for Alpha
function M.logo_colors()
    local o = M.opts
    return {
        a = brighten_hsl(vim.g.color9 or "#ff6b6b", o.lift_cols, o.satm_cols),
        b = brighten_hsl(vim.g.color13 or "#ff9cff", o.lift_cols, o.satm_cols),
        c = brighten_hsl(vim.g.color12 or "#87b3ff", o.lift_cols, o.satm_cols),
        d = brighten_hsl(vim.g.color10 or "#8df7a5", o.lift_cols, o.satm_cols),
        e = brighten_hsl(vim.g.color14 or "#a0e0ff", o.lift_cols, o.satm_cols),
    }
end

-- Public: apply Alpha* highlights (called after apply/save/load)
function M.reapply_alpha_highlights()
    local o = M.opts
    local base_bg = vim.g.color0 or "#0f0f0f"
    local base_fg = vim.g.color15 or "#e6e6e6"

    local alpha_bg = o.force_alpha_bg or set_min_lightness(base_bg, o.min_l_bg, o.satm_bg, o.lift_bg)
    local alpha_fg = brighten_hsl(base_fg, o.lift_fg, o.satm_fg)

    vim.api.nvim_set_hl(0, "AlphaNormal", { fg = alpha_fg, bg = alpha_bg })
    vim.api.nvim_set_hl(0, "AlphaEndOfBuffer", { fg = alpha_bg, bg = alpha_bg })
    vim.api.nvim_set_hl(0, "AlphaHeader", { fg = brighten_hsl(base_fg, 0.20, 0.95), bold = true })
    vim.api.nvim_set_hl(0, "AlphaShortcut", { fg = brighten_hsl(vim.g.color14 or "#a0e0ff", 0.25, 0.95), bold = true })
    vim.api.nvim_set_hl(0, "AlphaFooter", { fg = brighten_hsl(base_fg, 0.15, 1.0) })

    -- refresh the ASCII logo’s per-letter colors (for already-created groups)
    local lc = M.logo_colors()
    vim.api.nvim_set_hl(0, "Alphaa", { fg = lc.a })
    vim.api.nvim_set_hl(0, "Alphab", { fg = lc.b })
    vim.api.nvim_set_hl(0, "Alphac", { fg = lc.c })
    vim.api.nvim_set_hl(0, "Alphad", { fg = lc.d })
    vim.api.nvim_set_hl(0, "Alphae", { fg = lc.e })
end

-- ───────── Profile actions ─────────
function M.save(name)
    if not name or name == "" then
        vim.notify("WalProfiles: provide a name, e.g. :WalSaveTheme sunny-evening", vim.log.levels.WARN)
        return
    end
    ensure_dir(PROFILES)
    local dst = PROFILES .. "/" .. name
    ensure_dir(dst)

    local files = {
        WAL_CACHE .. "/colors.json",
        WAL_CACHE .. "/colors-wal.vim",
        WAL_CACHE .. "/colors",
        WAL_CACHE .. "/schemes/colors.sh",
    }
    for _, f in ipairs(files) do copy_if_exists(f, dst) end

    -- optional palette snapshot
    local pal = WAL_CACHE .. "/colors.json"
    if vim.fn.filereadable(pal) == 1 then
        local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(pal), "\n"))
        if ok and data and data.colors then
            vim.fn.writefile({ vim.inspect(data.colors) }, dst .. "/palette.lua")
        end
    end

    vim.notify("WalProfiles: saved theme → " .. name, vim.log.levels.INFO)
end

-- encode helper (nvim 0.9+: vim.json.encode; fallback to vim.fn.json_encode)
local function json_encode(tbl)
    local ok, mod = pcall(require, "vim.json")
    if ok and mod and mod.encode then return mod.encode(tbl) end
    return vim.fn.json_encode(tbl)
end

-- grab the CURRENT palette from vim.g (fallbacks if sparse)
local function capture_current_palette()
    local colors = {}
    for i = 0, 15 do
        local k = "color" .. i
        local v = vim.g[k]
        -- crude fallback: repeat last seen or default gray
        if type(v) ~= "string" or not v:match("^#%x%x%x%x%x%x$") then
            v = colors[k] or "#7f7f7f"
        end
        colors[k] = v
    end

    local bg = vim.g.background or colors.color0
    local fg = vim.g.foreground or colors.color7 or colors.color15

    return {
        colors  = colors,
        special = { background = bg, foreground = fg },
    }
end

-- write a profile dir from a palette table {colors=.., special=..}
local function write_profile_dir(dir, pal)
    ensure_dir(dir)
    -- colors.json (preferred by most loaders)
    vim.fn.writefile({ json_encode(pal) }, dir .. "/colors.json")

    -- plain "colors" file (16 lines)
    local lines = {}
    for i = 0, 15 do table.insert(lines, pal.colors["color" .. i]) end
    vim.fn.writefile(lines, dir .. "/colors")

    -- minimal colors-wal.vim (optional; harmless if unused)
    local walvim = {}
    for i = 0, 15 do
        table.insert(walvim, ("let g:color%d = '%s'"):format(i, pal.colors["color" .. i]))
    end
    table.insert(walvim, ("let g:background = '%s'"):format(pal.special.background))
    table.insert(walvim, ("let g:foreground = '%s'"):format(pal.special.foreground))
    vim.fn.writefile(walvim, dir .. "/colors-wal.vim")
end

-- turn anything into a safe folder name
local function sanitize_name(name)
    if type(name) ~= "string" then
        name = "current-" .. os.date("%Y%m%d-%H%M%S")
    end
    name = name:gsub("%s+", "-")         -- spaces -> hyphens
    name = name:gsub("[^%w%._%-]+", "_") -- remove slashes/colons/etc
    name = name:gsub("^[_%.%-]+", "")    -- trim leading junk
    if name == "" then
        name = "current-" .. os.date("%Y%m%d-%H%M%S")
    end
    return name:sub(1, 64) -- keep it short-ish
end


-- helper
local function sync_profile_to_wal_cache(dir)
    ensure_dir(WAL_CACHE)
    local files = {
        "colors.json",
        "colors-wal.vim",
        "colors",
        "schemes/colors.sh",
    }
    for _, f in ipairs(files) do
        local src = dir .. "/" .. f
        local dst = WAL_CACHE .. "/" .. f
        if vim.fn.filereadable(src) == 1 then
            ensure_dir(vim.fn.fnamemodify(dst, ":h"))
            vim.fn.writefile(vim.fn.readfile(src), dst)
        end
    end
end

function M.save_current(name)
    name = sanitize_name(name or ("current-" .. os.date("%Y%m%d-%H%M%S")))
    local pal = read_wal_cache_palette()
    if not pal then
        vim.notify("WalProfiles: no pywal cache found at " .. WAL_CACHE .. " (run `wal` first).", vim.log.levels.ERROR)
        return
    end
    local dir = PROFILES .. "/" .. name
    write_profile_dir(dir, pal)
    vim.notify("WalProfiles: saved CURRENT pywal → " .. name, vim.log.levels.INFO)
    return name
end

function M.apply(name)
    local dir = PROFILES .. "/" .. name
    if vim.fn.isdirectory(dir) == 0 then
        vim.notify("WalProfiles: profile not found: " .. name, vim.log.levels.ERROR)
        return
    end

    -- 1) load palette into vim.g (colors.json/colors)
    load_palette_from_dir(dir)

    -- 2) also copy the profile back to ~/.cache/wal so pywal sees it
    sync_profile_to_wal_cache(dir)

    -- 3) (optional) source colors-wal.vim in the profile
    local walvim = dir .. "/colors-wal.vim"
    if vim.fn.filereadable(walvim) == 1 then
        pcall(vim.cmd, "silent! source " .. walvim)
    end

    -- 4) persist selection
    ensure_dir(PROFILES)
    vim.fn.writefile({ name }, CURRENT)

    -- 5) if you use pywal.nvim, re-apply the colorscheme so it rereads ~/.cache/wal
    pcall(vim.cmd, "silent! colorscheme pywal")

    -- 6) refresh Alpha + redraw
    pcall(M.reapply_alpha_highlights)
    pcall(function()
        local ok, a = pcall(require, "alpha"); if ok and a.redraw then a.redraw() end
    end)

    vim.notify("WalProfiles: applied theme → " .. name, vim.log.levels.INFO)
end

function M.pick()
    local items = list_profiles()
    table.insert(items, 1, "➕ Save CURRENT as…") -- sentinel at top

    local function handle_choice(choice)
        if not choice then return end
        if choice == "➕ Save CURRENT as…" then
            vim.ui.input({ prompt = "Save current pywal as: " }, function(input)
                if not input or input == "" then return end
                local name = sanitize_name(input)
                local saved = M.save_current(name)
                if saved then M.apply(saved) end
            end)
            return
        end
        M.apply(choice)
    end

    local ok = pcall(require, "telescope")
    if ok then
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf    = require("telescope.config").values
        local actions = require("telescope.actions")
        local state   = require("telescope.actions.state")

        pickers.new({}, {
            prompt_title = "Wal Profiles",
            finder = finders.new_table(items),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(bufnr, _)
                actions.select_default:replace(function()
                    local entry = state.get_selected_entry()
                    actions.close(bufnr)
                    if entry and entry[1] then handle_choice(entry[1]) end
                end)
                return true
            end,
        }):find()
    else
        vim.ui.select(items, { prompt = "Select wal profile:" }, handle_choice)
    end
end

function M.delete(name)
    name = sanitize_name(name)
    local dir = PROFILES .. "/" .. name
    if vim.fn.isdirectory(dir) == 0 then
        vim.notify("WalProfiles: profile not found: " .. name, vim.log.levels.ERROR)
        return
    end

    vim.fn.delete(dir, "rf")

    -- if the deleted profile was the current one, forget it
    local cur = read_current_name()
    if cur == name then
        pcall(vim.fn.delete, CURRENT)
        vim.notify("WalProfiles: deleted CURRENT profile; keeping existing colors in-session.", vim.log.levels.WARN)
    end

    vim.notify("WalProfiles: deleted → " .. name, vim.log.levels.INFO)
end

function M.pick_delete()
    local items = list_profiles()
    if #items == 0 then
        vim.notify("WalProfiles: no saved profiles to delete.", vim.log.levels.WARN)
        return
    end

    local function act(choice)
        if not choice then return end
        -- small confirm to prevent accidents
        vim.ui.select({ "No", "Yes" }, { prompt = "Delete '" .. choice .. "'?" }, function(ans)
            if ans == "Yes" then M.delete(choice) end
        end)
    end

    local ok = pcall(require, "telescope")
    if ok then
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf    = require("telescope.config").values
        local actions = require("telescope.actions")
        local state   = require("telescope.actions.state")

        pickers.new({}, {
            prompt_title = "Delete Wal Profile",
            finder = finders.new_table(items),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(bufnr, _)
                actions.select_default:replace(function()
                    local entry = state.get_selected_entry()
                    actions.close(bufnr)
                    if entry and entry[1] then act(entry[1]) end
                end)
                return true
            end,
        }):find()
    else
        vim.ui.select(items, { prompt = "Delete wal profile:" }, act)
    end
end

function M.autoload_last()
    if vim.fn.filereadable(CURRENT) == 1 then
        local name = (vim.fn.readfile(CURRENT)[1] or ""):gsub("%s+$", "")
        if name ~= "" then M.apply(name) end
    end
end

-- ───────── Setup & commands ─────────
function M.setup(opts)
    -- merge user opts INTO defaults (not the other way around)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

    -- load current wal (harmless if absent) then autoload last profile
    pcall(vim.cmd, "silent! source " .. WAL_CACHE .. "/colors-wal.vim")
    if M.opts.autoload then
        M.autoload_last()
    else
        pcall(M.reapply_alpha_highlights)
    end

    vim.api.nvim_create_user_command("WalSaveTheme", function(a) M.save(a.args) end, { nargs = 1, complete = "file" })
    vim.api.nvim_create_user_command("WalPickTheme", function() M.pick() end, {})
    vim.api.nvim_create_user_command("WalApplyTheme", function(a) M.apply(a.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("WalPickDelete", function() M.pick_delete() end, {})

    vim.api.nvim_create_user_command("WalSaveCurrent", function(a)
        local name = sanitize_name(a.args ~= "" and a.args or ("current-" .. os.date("%Y%m%d-%H%M%S")))
        local saved = M.save_current(name)
        if saved then M.apply(saved) end
    end, { nargs = "?" })



    vim.api.nvim_create_user_command("WalDebugTheme", function()
        local cur = (vim.fn.filereadable(CURRENT) == 1) and (vim.fn.readfile(CURRENT)[1] or "") or "(none)"
        local c0  = vim.g.color0 or "nil"
        local c7  = vim.g.color7 or "nil"
        local c15 = vim.g.color15 or "nil"
        local bg  = vim.g.background or "nil"
        local fg  = vim.g.foreground or "nil"
        vim.notify(("WalDebug:\n current=%s\n color0=%s\n color7=%s\n color15=%s\n bg=%s fg=%s")
            :format(cur, c0, c7, c15, bg, fg), vim.log.levels.INFO)
    end, {})
end

return M
