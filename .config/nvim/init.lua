-- Path for lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

vim.opt.number = true
require("vim-options")
require("lazy").setup("plugins")

local config_path = vim.fn.stdpath("config")
local target_dir = config_path .. "/lua/config"

if not (vim.uv or vim.loop).fs_stat(target_dir) then
    vim.notify("config dir not found: " .. target_dir, vim.log.levels.WARN)
    return
end

local ok, lua_files = pcall(vim.fn.readdir, target_dir, function(name)
    return name:match("%.lua$") ~= nil
end)

if not ok then
    vim.notify("readdir failed for " .. target_dir, vim.log.levels.ERROR)
    return
end

for _, file in ipairs(lua_files) do
    local mod = "config." .. file:gsub("%.lua$", "")
    local ok_mod, err = pcall(require, mod)
    if not ok_mod then
        vim.notify("Failed to load " .. mod .. ": " .. err, vim.log.levels.ERROR)
    end
end

require("config.wal_profiles").setup()
