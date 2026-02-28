-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ neovim/nvim-lspconfig                                                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  'neovim/nvim-lspconfig',
  dependencies = {
    {
      'SmiteshP/nvim-navbuddy',
      dependencies = { 'SmiteshP/nvim-navic', 'MunifTanjim/nui.nvim' },
      opts = { lsp = { auto_attach = true } },
    },
  },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    if not (vim.lsp and vim.lsp.config and vim.lsp.enable) then
      vim.notify('vim.lsp.config requires Neovim 0.11+', vim.log.levels.WARN)
      return
    end

    vim.diagnostic.config({
      virtual_text = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = '',
          [vim.diagnostic.severity.WARN]  = '',
          [vim.diagnostic.severity.HINT]  = '',
          [vim.diagnostic.severity.INFO]  = '',
        },
      },
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = { border = 'rounded', source = 'if_many' },
    })

    if vim.lsp.inlay_hint then
      local group = vim.api.nvim_create_augroup('NegLspInlayHints', { clear = true })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(event)
          vim.keymap.set('n', '<leader>uh', function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = event.buf })
          end, { buffer = event.buf, desc = 'Inlay Hints: toggle' })
        end,
      })
    end

    -- Blink interaction
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    if pcall(require, 'blink.cmp') then
      capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)
    end

    local base_config = {
      capabilities = capabilities,
    }

    -- configure: set custom config; optionally enable (for non-Mason servers)
    local function configure(server, extra, enable)
      local resolved = vim.tbl_deep_extend('force', {}, base_config, extra or {})
      vim.lsp.config(server, resolved)
      if enable then vim.lsp.enable(server) end
    end

    -- System-installed servers (pacman/AUR — not managed by Mason, must enable manually)
    configure('cmake', nil, true)
    configure('systemd_ls', nil, true)

    -- Mason-managed servers: config only, mason-lspconfig handles enable via automatic_enable
    configure('clangd', {
      cmd = { 'clangd', '--background-index', '--clang-tidy', '--completion-style=detailed', '--header-insertion=never' },
      init_options = { clangdFileStatus = true },
    })
    configure('jsonls', {
      filetypes = { 'json', 'jsonc', 'json5' },
    })
    configure('pyright', {
      settings = {
        python = {
          analysis = {
            typeCheckingMode = 'basic',
            autoImportCompletions = true,
          },
        },
      },
    })

    -- Global LSP/Help keymaps (replace vim-ref behavior)
    vim.keymap.set('n', 'K', function()
      local clients = {}
      if vim.lsp and vim.lsp.get_clients then
        clients = vim.lsp.get_clients({ bufnr = 0 })
      end
      if clients and #clients > 0 then
        return vim.lsp.buf.hover()
      end
      local word = vim.fn.expand('<cword>')
      if word ~= '' then
        vim.cmd('help ' .. word)
      end
    end, { desc = 'Hover or :help cword' })

    vim.keymap.set('n', 'gd', function()
      local clients = {}
      if vim.lsp and vim.lsp.get_clients then
        clients = vim.lsp.get_clients({ bufnr = 0 })
      end
      if clients and #clients > 0 then
        return vim.lsp.buf.definition()
      end
      -- Fallback: try tag jump when no LSP available
      pcall(vim.cmd, 'tag ' .. vim.fn.expand('<cword>'))
    end, { desc = 'Go to definition (LSP/tag)' })
  end,
}
