vim.g.mapleader = ','
Map('i', '<C-j>', '<ESC>', {nowait = true, desc = 'Escape'})
Map('v', '<C-j>', '<ESC>', {nowait = true, desc = 'Escape'})
for _, key in ipairs({ 'j', 'k', 'l', 'h' }) do
  Map('n', '<leader>' .. key, '<C-w>' .. key, { nowait = true, desc = 'Window ' .. key })
end
Map('n', '_', "<Cmd>exe 'e ' . getcwd()<CR>", {desc = 'Open cwd'})

Map('t', '<Esc>', '<C-\\><C-n>', {silent=true, desc = 'Terminal escape'})

Map('n', 'Q', 'q', {noremap=true, desc = 'Record macro'})
for _, key in ipairs({ 'q', '<F1>', '<up>', '<down>', '<left>', '<right>' }) do
  Map('', key, '<NOP>')
end

Map('v', '<C-e>', '"+y', {silent=true, noremap=true, desc = 'Yank to clipboard'})

Map('n', 'en', '<Cmd>cnext<CR>', {silent=true, desc = 'Quickfix next'})
Map('n', 'ep', '<Cmd>cprevious<CR>', {silent=true, desc = 'Quickfix prev'})
Map('n', 'eR', '<Cmd>crewind<CR>', {silent=true, desc = 'Quickfix rewind'})
Map('n', 'eN', '<Cmd>cfirst<CR>', {silent=true, desc = 'Quickfix first'})
Map('n', 'eP', '<Cmd>clast<CR>', {silent=true, desc = 'Quickfix last'})
Map('n', 'el', '<Cmd>clist<CR>', {silent=true, desc = 'Quickfix list'})

Map('n', 'ew', '<Cmd>w!<CR>', {silent=true, desc = 'Force write'})
Map('n', 'eW', '<Cmd>SudaWrite<CR>', {silent=true, desc = 'Sudo write'})
Map('n', 'eS', '<Cmd>source %<CR>', {silent=true, desc = 'Source current file'})
Map('n', 'eU', '<Cmd>Lazy update<CR>', {silent=true, desc = 'Lazy update'})
Map('n', '<C-c>', '<C-[>')
Map('i', '<C-c>', '<C-[>')
-- These create newlines like o and O but stay in normal mode
Map('n', 'zJ', 'o<Esc>k', {silent=true, desc = 'Newline below (stay normal)'})
Map('n', 'zK', 'O<Esc>j', {silent=true, desc = 'Newline above (stay normal)'})
-- Toggle hlsearch for current results, start highlight
Map('n', ',,', '<Cmd>nohlsearch<CR><Cmd>diffupdate<CR><Cmd>syntax sync fromstart<CR><C-l>', {desc = 'Clear highlights'})
-- Visual shifting (does not exit Visual mode)
Map('v', '<', '<gv')
Map('v', '>', '>gv')
Map('n', '<C-g>', 'g<C-g>')
-- Swap implementations of ` and ' jump to markers
-- By default, ' jumps to the marked line, ` jumps to the marked line and
-- column, so swap them
Map('n', "'", "`")
Map('n', "`", "'")
Map('n', '<M-w>', '<Cmd>bd<CR>', {silent=true, desc = 'Delete buffer'})
Map('i', '<C-V>', '<C-R>+')
Map('c', '<C-a>', '<home>', {noremap=true})
Map('i', '<C-a>', "<C-o>^", {noremap=true})
Map('c', '<C-n>', '<down>', {noremap=true})
Map('c', '<C-p>', '<up>', {noremap=true})
Map({'c','i'}, '<C-b>', '<left>', {noremap=true})
Map({'c','i'}, '<C-d>', '<Del>', {noremap=true})
Map({'c','i'}, '<C-f>', '<right>', {noremap=true})
Map('c', '<M-f>', '<S-Right>', {noremap=true})
Map('i', '<M-f>', '<C-o>e<Right>', {noremap=true})
Map({'c','i'}, '<M-b>', '<S-Left>', {noremap=true})
Map('c', '<M-d>', '<S-Right><C-w>', {noremap=true})
Map('i', '<M-d>', '<C-o>dw', {noremap=true})
Map('o', '<M-b>', '<Left>', {noremap=true})
Map('o', '<M-e>', '<End>', {noremap=true})
Map('i', '<C-e>', "<C-o>$", {noremap=true})

Map('n', 'et', function() require('75-smart-cd').smart_cd() end, {desc = 'Smart directory change'})
-- <CR> in normal mode: open bare URL under cursor, NOP otherwise (redundant with j/+)
Map('n', '<CR>', function()
  local line = vim.api.nvim_get_current_line()
  local col  = vim.api.nvim_win_get_cursor(0)[2] + 1
  local i = 1
  while true do
    local s, e, url = line:find('(https?://%S+)', i)
    if not s then break end
    if col >= s and col <= e then
      require('utils.nav').open_url(url)
      return
    end
    i = e + 1
  end
end, { desc = 'Open URL under cursor' })
