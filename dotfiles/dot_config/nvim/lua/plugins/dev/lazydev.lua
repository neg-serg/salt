-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ folke/lazydev.nvim                                                           │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      -- Extra type libraries to inject into lua-ls
      library = {
        -- luv/uv types for vim.uv / vim.loop
        { path = "${3rd}/luv/library", words = { "vim%.uv", "vim%.loop" } },
        -- Optional examples (uncomment if you need them):
        { path = "${3rd}/busted/library", words = { "describe", "it", "before_each", "after_each" } },
        { path = "${3rd}/luassert/library", words = { "assert" } },
        { path = "${3rd}/luafun/library", words = { "fun%." } },
      },

      -- Enable faster indexing
      fast = true,

      -- Treat identifiers starting with "_" as private
      private = { "^_" },
    },
  },
}
