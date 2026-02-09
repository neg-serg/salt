-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ mason.nvim — portable LSP/formatter/linter installer                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  'mason-org/mason.nvim',
  lazy = false,
  dependencies = {
    {
      'mason-org/mason-lspconfig.nvim',
      opts = {
        ensure_installed = {
          'autotools_ls',
          'awk_ls',
          'bashls',
          'clangd',
          'cmake',
          'cssls',
          'dotls',
          'html',
          'jsonls',
          'lemminx',
          'marksman',
          'nil_ls',
          'pyright',
          'qmlls',
          'taplo',
          'ts_ls',
          'yamlls',
        },
      },
    },
    {
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      opts = {
        ensure_installed = {
          'prettierd',
          'stylua',
        },
      },
    },
  },
  opts = {},
}
