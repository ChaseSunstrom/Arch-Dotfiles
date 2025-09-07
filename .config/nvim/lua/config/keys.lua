-- keys.lua
-- Opinionated, minimal helpers for windows, splits, resizing, and buffers.

-- tiny helpers
local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end

local has = function(mod)
  local ok = pcall(require, mod)
  return ok
end

-- Prefer bufdelete if available, otherwise do a safe fallback that keeps the layout
local delete_buf = function(force)
  if has("bufdelete") then
    require("bufdelete").bufdelete(0, force)
  else
    -- if only one listed buffer, just wipe it; otherwise switch then delete to keep window
    local listed = vim.tbl_filter(function(b) return vim.bo[b].buflisted end, vim.api.nvim_list_bufs())
    if #listed > 1 then
      vim.cmd(force and "bp | bd! #" or "bp | bd #")
    else
      vim.cmd(force and "bd!" or "bd")
    end
  end
end

  ---------------------------
  -- WINDOW NAVIGATION
  ---------------------------
  map("n", "<C-h>", "<C-w>h", "Window left")
  map("n", "<C-j>", "<C-w>j", "Window down")
  map("n", "<C-k>", "<C-w>k", "Window up")
  map("n", "<C-l>", "<C-w>l", "Window right")

  -- Terminal-mode window nav (handy if you use :terminal)
  map("t", "<C-h>", "<C-\\><C-n><C-w>h", "Window left (term)")
  map("t", "<C-j>", "<C-\\><C-n><C-w>j", "Window down (term)")
  map("t", "<C-k>", "<C-\\><C-n><C-w>k", "Window up (term)")
  map("t", "<C-l>", "<C-\\><C-n><C-w>l", "Window right (term)")

  ---------------------------
  -- SPLITS & LAYOUT
  ---------------------------
  map("n", "<leader>sv", "<C-w>v", "Split vertical")
  map("n", "<leader>sh", "<C-w>s", "Split horizontal")
  map("n", "<leader>sc", "<C-w>c", "Close window")
  map("n", "<leader>s=", "<C-w>=", "Equalize splits")
  map("n", "<leader>sr", "<C-w>r", "Rotate layout")

  -- Quick “maximize current” (press again to equalize)
  map("n", "<leader>sm", function()
    local view = vim.w.__maximized
    if view then
      vim.w.__maximized = nil
      vim.cmd("wincmd =")
    else
      vim.w.__maximized = true
      vim.cmd("wincmd _ | wincmd |")
    end
  end, "Toggle maximize split")

  ---------------------------
  -- RESIZING (Alt + h/j/k/l)
  ---------------------------
  map("n", "<A-h>", "2<C-w><", "Resize left")
  map("n", "<A-l>", "2<C-w>>", "Resize right")
  map("n", "<A-j>", "1<C-w>-", "Resize down")
  map("n", "<A-k>", "1<C-w>+", "Resize up")

  ---------------------------
  -- BUFFERS
  ---------------------------
  -- Cycle
  map("n", "<S-l>", ":bnext<CR>", "Next buffer")
  map("n", "<S-h>", ":bprevious<CR>", "Prev buffer")
  map("n", "<leader><Tab>", "<C-^>", "Alternate buffer")

  -- List / picker
  if has("telescope.builtin") then
    map("n", "<leader>bl", function() require("telescope.builtin").buffers() end, "List buffers")
  else
    map("n", "<leader>bl", ":ls<CR>", "List buffers")
  end

  -- Close (keep window), force close
  map("n", "<leader>bd", function() delete_buf(false) end, "Delete buffer")
  map("n", "<leader>bD", function() delete_buf(true) end, "Delete buffer (force)")

  -- Wipe all but current (great for cleanup)
  map("n", "<leader>bo", function()
    local current = vim.api.nvim_get_current_buf()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buflisted and b ~= current then
        vim.api.nvim_buf_delete(b, { force = false })
      end
    end
  end, "Only current buffer")

  ---------------------------
  -- TABS (lightweight)
  ---------------------------
  map("n", "<leader>tn", ":tabnew<CR>", "New tab")
  map("n", "<leader>tq", ":tabclose<CR>", "Close tab")
  map("n", "<leader>to", ":tabonly<CR>", "Only this tab")
  map("n", "<C-PageUp>", "gT", "Prev tab")
  map("n", "<C-PageDown>", "gt", "Next tab")

  ---------------------------
  -- QUALITY-OF-LIFE EXTRAS
  ---------------------------
  map("n", "<leader>w", ":w<CR>", "Save")
  map("n", "<leader>q", ":q<CR>", "Quit")
  map({ "n", "x" }, "gy", '"+y', "Yank to system clipboard")
  map("n", "Y", "y$", "Yank to end of line")
  map("n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")


