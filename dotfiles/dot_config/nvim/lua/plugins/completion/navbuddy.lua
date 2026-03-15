-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ SmiteshP/nvim-navbuddy — deferred to LspAttach                             │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  'SmiteshP/nvim-navbuddy',
  event = 'LspAttach',
  dependencies = { 'SmiteshP/nvim-navic', 'MunifTanjim/nui.nvim' },
  opts = { lsp = { auto_attach = true } },
}
