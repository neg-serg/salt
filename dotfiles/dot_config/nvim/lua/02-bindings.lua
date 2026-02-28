local map = vim.keymap.set
map('i', '<C-j>', '<ESC>', {nowait = true, desc = 'Escape'})
map('v', '<C-j>', '<ESC>', {nowait = true, desc = 'Escape'})
for _, key in ipairs({ 'j', 'k', 'l', 'h' }) do
  map('n', '<leader>' .. key, '<C-w>' .. key, { nowait = true, desc = 'Window ' .. key })
end
map('n', '_', "<Cmd>exe 'e ' . getcwd()<CR>", {desc = 'Open cwd'})

map('t', '<Esc>', '<C-\\><C-n>', {silent=true, desc = 'Terminal escape'})

map('n', 'Q', 'q', {noremap=true, desc = 'Record macro'})
for _, key in ipairs({ 'q', '<F1>', '<up>', '<down>', '<left>', '<right>' }) do
  map('', key, '<NOP>')
end

map('v', '<C-e>', '"+y', {silent=true, noremap=true, desc = 'Yank to clipboard'})

map('n', 'en', '<Cmd>cnext<CR>', {silent=true, desc = 'Quickfix next'})
map('n', 'ep', '<Cmd>cprevious<CR>', {silent=true, desc = 'Quickfix prev'})
map('n', 'eR', '<Cmd>crewind<CR>', {silent=true, desc = 'Quickfix rewind'})
map('n', 'eN', '<Cmd>cfirst<CR>', {silent=true, desc = 'Quickfix first'})
map('n', 'eP', '<Cmd>clast<CR>', {silent=true, desc = 'Quickfix last'})
map('n', 'el', '<Cmd>clist<CR>', {silent=true, desc = 'Quickfix list'})

map('n', 'ew', '<Cmd>w!<CR>', {silent=true, desc = 'Force write'})
map('n', 'eW', '<Cmd>SudaWrite<CR>', {silent=true, desc = 'Sudo write'})
map('n', 'eS', '<Cmd>source %<CR>', {silent=true, desc = 'Source current file'})
map('n', 'eU', '<Cmd>Lazy update<CR>', {silent=true, desc = 'Lazy update'})
map('n', '<C-c>', '<C-[>')
map('i', '<C-c>', '<C-[>')
-- These create newlines like o and O but stay in normal mode
map('n', 'zJ', 'o<Esc>k', {silent=true, desc = 'Newline below (stay normal)'})
map('n', 'zK', 'O<Esc>j', {silent=true, desc = 'Newline above (stay normal)'})
-- Toggle hlsearch for current results, start highlight
map('n', ',,', '<Cmd>nohlsearch<CR><Cmd>diffupdate<CR><Cmd>syntax sync fromstart<CR><C-l>', {desc = 'Clear highlights'})
-- Visual shifting (does not exit Visual mode)
map('v', '<', '<gv')
map('v', '>', '>gv')
map('n', '<C-g>', 'g<C-g>')
-- Swap implementations of ` and ' jump to markers
-- By default, ' jumps to the marked line, ` jumps to the marked line and
-- column, so swap them
map('n', "'", "`")
map('n', "`", "'")
map('n', '<M-w>', '<Cmd>bd<CR>', {silent=true, desc = 'Delete buffer'})
map('i', '<C-V>', '<C-R>+')
map('c', '<C-a>', '<home>', {noremap=true})
map('i', '<C-a>', "<C-o>^", {noremap=true})
map('c', '<C-n>', '<down>', {noremap=true})
map('c', '<C-p>', '<up>', {noremap=true})
map({'c','i'}, '<C-b>', '<left>', {noremap=true})
map({'c','i'}, '<C-d>', '<Del>', {noremap=true})
map({'c','i'}, '<C-f>', '<right>', {noremap=true})
map('c', '<M-f>', '<S-Right>', {noremap=true})
map('i', '<M-f>', '<C-o>e<Right>', {noremap=true})
map({'c','i'}, '<M-b>', '<S-Left>', {noremap=true})
map('c', '<M-d>', '<S-Right><C-w>', {noremap=true})
map('i', '<M-d>', '<C-o>dw', {noremap=true})
map('o', '<M-b>', '<Left>', {noremap=true})
map('o', '<M-e>', '<End>', {noremap=true})
map('i', '<C-e>', "<C-o>$", {noremap=true})

map('n', 'et', function() require('75-smart-cd').smart_cd() end, {desc = 'Smart directory change'})
-- <CR> in normal mode: smart link follower
-- Cascade: URL → LSP definition → gf → NOP (never redundant j-move)
-- Filetype-specific overrides (ftplugin/) take precedence via buffer-local mappings.
map('n', '<CR>', function()
  -- Preserve built-in <CR> in quickfix (jump to entry) and prompt buffers
  local bt = vim.bo.buftype
  if bt == 'quickfix' or bt == 'prompt' then
    return vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
  end

  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- 1. URL under cursor (http://, https://, file://)
  for _, pattern in ipairs({'(https?://%S+)', '(file://%S+)'}) do
    local i = 1
    while true do
      local s, e, url = line:find(pattern, i)
      if not s then break end
      if col >= s and col <= e then
        require('utils.nav').open_url(url)
        return
      end
      i = e + 1
    end
  end

  -- 2. LSP go-to-definition (when server supports it and cursor is on a word)
  local word = vim.fn.expand('<cword>')
  if word ~= '' then
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      if client:supports_method('textDocument/definition') then
        vim.lsp.buf.definition()
        return
      end
    end
  end

  -- 3. gf: follow file path under cursor (silently NOP if nothing found)
  pcall(vim.cmd, 'normal! gf')
end, { desc = 'Smart follow: URL → LSP def → file' })
