-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ folke/flash.nvim                                                             │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  "folke/flash.nvim",
  enabled = false, -- disabled: using leap.nvim + flit.nvim instead
  opts = {},
  keys = {
    {
      "<space>",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump()
      end,
      desc = "Flash",
    },
  },
}
