-- create a group so you can clear/reload cleanly
local augroup = vim.api.nvim_create_augroup("LspFormat", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(args)
    vim.lsp.buf.format({ bufnr = args.buf, async = false })
  end,
})

