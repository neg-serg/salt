-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ mason.nvim — portable LSP/formatter/linter installer                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  {
    'mason-org/mason.nvim',
    lazy = false,
    opts = {},
  },
  {
    'mason-org/mason-lspconfig.nvim',
    lazy = false,
    dependencies = {
      'mason-org/mason.nvim',
      'neovim/nvim-lspconfig',
    },
    opts = {
      automatic_enable = false,
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
        'just',
        'lemminx',
        'marksman',
        'nginx_language_server',
        'nil_ls',
        'pyright',
        'qmlls',
        'systemd_ls',
        'taplo',
        'ts_ls',
        'yamlls',
      },
    },
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    lazy = false,
    dependencies = { 'mason-org/mason.nvim' },
    opts = {
      ensure_installed = {
        'prettierd',
        'stylua',
      },
    },
  },
}
