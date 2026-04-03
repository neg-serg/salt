-- Minimal Neovim config for kitty-scrollback.nvim
-- Loaded via: nvim -u ~/.config/ksb-nvim/init.lua
-- Keeps scrollback launch fast by only loading the one plugin needed.

local ksb_path = vim.fn.stdpath('data') .. '/lazy/kitty-scrollback.nvim'
if not vim.uv.fs_stat(ksb_path) then
  vim.notify('kitty-scrollback.nvim not found at ' .. ksb_path, vim.log.levels.ERROR)
  return
end
vim.opt.rtp:prepend(ksb_path)

-- ── Minimal options ──────────────────────────────────────────────────
vim.g.mapleader = ' '
vim.opt.termguicolors = true
vim.opt.number = false
vim.opt.relativenumber = false

-- ── Colorscheme ──────────────────────────────────────────────────────
pcall(function()
  local neg_path = vim.fn.stdpath('data') .. '/lazy/neg.nvim'
  if vim.uv.fs_stat(neg_path) then
    vim.opt.rtp:append(neg_path)
  end
  pcall(vim.cmd.colorscheme, 'neg')
end)

-- ── Yank helpers: copy selection to clipboard, optionally close ──────
local function should_quit_after_yank()
  if vim.g.kitty_scrollback_quit_after_yank ~= nil then
    return not (vim.g.kitty_scrollback_quit_after_yank == false
             or vim.g.kitty_scrollback_quit_after_yank == 0)
  end
  local v = vim.env.KITTY_SCROLLBACK_QUIT_AFTER_YANK
  if v ~= nil then
    v = tostring(v):lower()
    return not (v == '0' or v == 'false' or v == 'no')
  end
  return true
end

local function yank_and_maybe_quit()
  local keys = vim.api.nvim_replace_termcodes('"+y', true, false, true)
  vim.api.nvim_feedkeys(keys, 'x', false)
  if should_quit_after_yank() then
    local ok, api = pcall(require, 'kitty-scrollback.api')
    if ok then api.quit_all() else pcall(vim.cmd, 'qa!') end
  end
end

vim.keymap.set('v', 'Y',    yank_and_maybe_quit, { noremap = true, silent = true })
vim.keymap.set('v', '<CR>', yank_and_maybe_quit, { noremap = true, silent = true })

-- ── Plugin setup ─────────────────────────────────────────────────────
require('kitty-scrollback').setup({
  status_window = { show_timer = true },
  kitty_get_text = {
    ansi = true,
    extent = 'all',
    clear_selection = true,
  },
  paste_window = {
    yank_register_enabled = false,
    hide_footer = true,
  },
})
