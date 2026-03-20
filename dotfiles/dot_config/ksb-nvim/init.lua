-- Minimal Neovim config for kitty-scrollback.nvim
-- Loaded via: nvim -u ~/.config/ksb-nvim/init.lua
-- Keeps scrollback launch fast by only loading the one plugin needed.

local ksb_path = vim.fn.stdpath('data') .. '/lazy/kitty-scrollback.nvim'
if not vim.uv.fs_stat(ksb_path) then
  vim.notify('kitty-scrollback.nvim not found at ' .. ksb_path, vim.log.levels.ERROR)
  return
end

vim.opt.rtp:prepend(ksb_path)

require('kitty-scrollback').setup({
  status_window = { show_timer = true },
  kitty_get_text = {
    ansi = true,
    extent = 'all',
    clear_selection = true,
  },
})
