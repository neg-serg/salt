-- :profile start profile.log
-- :profile func *
-- :profile file *
-- " At this point do slow actions
-- :profile pause
-- :noautocmd qall!
if vim.fn.has("nvim-0.9.2") ~= 1 then
    local message=table.concat({"You are using an unsupported version of Neovim."}, "\n")
    vim.notify(message, vim.log.levels.ERROR)
end
if vim.loader then vim.loader.enable() end
vim.g.mapleader = ','
vim.g.maplocalleader = ','
require'00-settings'
require'01-plugins'

-- Defer all non-critical modules to after first screen render
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy', once = true,
  callback = function()
    require'02-bindings'
    require'04-aucmds'
    require'08-cmds'
    require'14-abbr'
    require'62-sort-operator'
  end,
})


