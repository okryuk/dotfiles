-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	command = "set nopaste",
})

-- Disable the concealing in some file formats
-- The default conceallevel is 3 in LazyVim
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc", "markdown" },
	callback = function()
		vim.opt.conceallevel = 0
	end,
})

-- Set local tab width to 4 while working on go files.
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
	pattern = { "*.go" },
	command = "setlocal noet ts=4 sw=4 sts=4",
})

-- Run go formatting and gopackages on file saving
--vim.api.nvim_create_autocmd({ "BufWritePre" }, {
--	pattern = "*.go",
--	callback = function()
--		vim.lsp.buf.format()
--		vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
--	end,
--})
