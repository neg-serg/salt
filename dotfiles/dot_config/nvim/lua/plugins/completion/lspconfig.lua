-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ neovim/nvim-lspconfig                                                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  'neovim/nvim-lspconfig',
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

    do
      local group = vim.api.nvim_create_augroup('NegLspAttach', { clear = true })
      vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(event)
          local buf = event.buf
          local function bmap(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
          end
          bmap('n', 'gr', vim.lsp.buf.references, 'LSP: references')
          bmap('n', 'gi', vim.lsp.buf.implementation, 'LSP: implementation')
          bmap({'n', 'v'}, '<leader>ca', vim.lsp.buf.code_action, 'LSP: code action')
          bmap('n', '<leader>D', vim.lsp.buf.type_definition, 'LSP: type definition')
          bmap('n', '<leader>ws', vim.lsp.buf.workspace_symbol, 'LSP: workspace symbol')
          bmap('n', '<leader>ds', vim.lsp.buf.document_symbol, 'LSP: document symbol')
          if vim.lsp.inlay_hint then
            bmap('n', '<leader>uh', function()
              local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
              vim.lsp.inlay_hint.enable(not enabled, { bufnr = buf })
            end, 'Inlay Hints: toggle')
          end
        end,
      })
    end

    -- Blink interaction: merge capabilities without forcing eager load
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    if package.loaded['blink.cmp'] then
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
