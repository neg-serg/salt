-- Appearance plugins (excluding neg.nvim colorscheme which has its own spec)
return {
  -- │ █▓▒░ aileot/ex-colors.nvim                                                   │
  -- Extract current highlight definitions and generate a fast ex-<scheme>.
  {
    'aileot/ex-colors.nvim',
    cmd = { 'ExColors' },
    opts = {},
  },

  -- │ █▓▒░ HiPhish/rainbow-delimiters.nvim                                          │
  {
    'HiPhish/rainbow-delimiters.nvim',
    event = { "BufReadPost", "BufNewFile" },
    submodules = false,
    version = '*',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config=function()
      local rainbow_delimiters=require'rainbow-delimiters'
      vim.g.rainbow_delimiters={
        strategy={
          ['']=rainbow_delimiters.strategy['global'],
          vim=rainbow_delimiters.strategy['local'],
        },
        query={
          ['']='rainbow-delimiters',
          lua = (function()
            local ok, q = pcall(function()
              local has
              if vim.treesitter.query and vim.treesitter.query.get then
                has = pcall(vim.treesitter.query.get, 'lua', 'rainbow-blocks')
              elseif vim.treesitter.get_query then
                has = pcall(vim.treesitter.get_query, 'lua', 'rainbow-blocks')
              end
              return has and 'rainbow-blocks' or 'rainbow-delimiters'
            end)
            return ok and q or 'rainbow-delimiters'
          end)(),
        },
        highlight={
          'RainbowDelimiterRed',
          'RainbowDelimiterYellow',
          'RainbowDelimiterBlue',
          'RainbowDelimiterOrange',
          'RainbowDelimiterGreen',
          'RainbowDelimiterViolet',
          'RainbowDelimiterCyan',
        },
      }
    end
  },

  -- │ █▓▒░ nvim-treesitter/nvim-treesitter                                           │
  {
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
  },
}
