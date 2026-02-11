-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ smjonas/inc-rename.nvim                                                      │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
  "smjonas/inc-rename.nvim",
  cmd = "IncRename",
  keys = {
    { "<leader>rn", function() return ":IncRename " .. vim.fn.expand("<cword>") end, expr = true, desc = "Rename (inc-rename)" },
  },
  config = function()
    require("inc_rename").setup()
  end,
}
