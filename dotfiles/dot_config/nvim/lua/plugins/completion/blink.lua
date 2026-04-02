-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ Saghen/blink.cmp                                                             │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'saghen/blink.cmp',
  event = { "InsertEnter", "CmdlineEnter" },
  lazy = true,
  dependencies = { 'rafamadriz/friendly-snippets' }, -- optional: provides snippets for the snippet source
  version = '1.*', -- use a release tag to download pre-built binaries
  init = function()
    -- Update LSP capabilities when blink loads after lspconfig
    vim.api.nvim_create_autocmd('User', {
      pattern = 'LazyLoad',
      callback = function(ev)
        if ev.data ~= 'blink.cmp' then return end
        local caps = require('blink.cmp').get_lsp_capabilities(
          vim.lsp.protocol.make_client_capabilities()
        )
        for _, client in ipairs(vim.lsp.get_clients()) do
          client.capabilities = vim.tbl_deep_extend('force', client.capabilities, caps)
        end
        return true -- remove autocmd
      end,
    })
  end,
  opts = {
    keymap = { preset = 'super-tab' }, -- See :h blink-cmp-config-keymap for defining your own keymap
    appearance = { nerd_font_variant = 'mono'},
    completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', 'minuet' },
      providers = {
        minuet = {
          name = 'minuet',
          module = 'minuet.blink',
          score_offset = 100,
        },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" }
}
