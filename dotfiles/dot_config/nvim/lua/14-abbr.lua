-- ── Command-line abbreviations ───────────────────────────────────────
local function abbrev(lhs, rhs)
  vim.cmd.cnoreabbrev(lhs .. ' ' .. rhs)
end

-- Typo corrections
vim.cmd('cabbrev W! w!')
abbrev('W', 'w')
abbrev('Bd', 'bd')
abbrev('Cp', 'cp')
abbrev('E', 'e')
abbrev('Sp', 'sp')
abbrev('VS', 'vs')
abbrev('Q', 'q')
abbrev('Q!', 'q!')
abbrev('Qa', 'qa')
abbrev('QA', 'qa')
abbrev('QA!', 'qa!')
abbrev('Wq', 'wq')
abbrev('WQ', 'wq')
abbrev('wQ', 'wq')

-- Git shortcuts
abbrev('gb', 'FzfLua git_branches')
abbrev('gc', 'Git commit -v -m')
abbrev('gca', 'Git commit --amend -v')
abbrev('gcc', 'Git checkout')
abbrev('gd', 'Gvdiff')
abbrev('gl', 'FzfLua git_commits')
abbrev('gmv', 'Gmove')
abbrev('gp', 'Gpush')
abbrev('grm', 'Gremove')
abbrev('gs', 'FzfLua git_status')

-- Misc
abbrev('mkdir', 'Mkdir')
abbrev('T', 'FzfLua')

-- ── Smart CR: expand abbreviations on keyword-only cmdlines ─────────
vim.keymap.set('c', '<CR>', function()
  local cmdline = vim.fn.getcmdline()
  if cmdline:match('^%w+$') then
    -- Trigger abbreviation expansion (<C-]>) then execute (<CR>)
    return vim.api.nvim_replace_termcodes('<C-]><CR>', true, false, true)
  end
  return vim.api.nvim_replace_termcodes('<CR>', true, false, true)
end, { expr = true })
