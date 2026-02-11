-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ nvim-treesitter/nvim-treesitter                                              │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  'nvim-treesitter/nvim-treesitter',
  event = { 'BufReadPost', 'BufNewFile' },
  config = function()
    require('nvim-treesitter').setup()
    vim.api.nvim_create_autocmd('FileType', {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
