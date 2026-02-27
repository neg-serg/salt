local au = vim.api.nvim_create_autocmd
local gr = vim.api.nvim_create_augroup

local main = gr("main", {clear=true})
local shada = gr("shada", {clear=true})
local utils = gr("utils", {clear=true})
local mode_change = gr("mode_change", {clear=true})
local custom_updates = gr("custom_updates", {clear=true})
local hi_yank = gr("hi_yank", {clear=true})

-- Auto set window-local cwd to project root for reliable gf/path resolution.
-- Root detection delegates to utils/nav.lua (cached, unified marker set).
do
  local pr = gr('AutoProjectRoot', { clear = true })
  au({ 'BufEnter', 'BufNewFile' }, {
    group = pr,
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if not name or name == '' then return end
      local filedir = vim.fn.fnamemodify(name, ':p:h')
      local ok, nav = pcall(require, 'utils.nav')
      local root = ok and nav.project_root(filedir) or filedir
      if root and vim.fn.getcwd(0) ~= root then pcall(vim.cmd.lcd, root) end
    end,
    desc = 'Auto-set local cwd to project root',
  })
end

-- Ensure user ftplugins are applied even when built-in ftplugin.vim is disabled.
-- (loaded_ftplugin=1 in 00-settings.lua blocks Neovim's autoload mechanism.)
do
  local function load_ftplugin(ft_file)
    return function()
      pcall(dofile, vim.fn.stdpath('config') .. '/ftplugin/' .. ft_file .. '.lua')
    end
  end
  au('FileType', {
    group = gr('UserFtpluginMarkdown', { clear = true }),
    pattern = 'markdown',
    callback = load_ftplugin('markdown'),
    desc = 'Load user ftplugin/markdown.lua',
  })
  au('FileType', {
    group = gr('UserFtpluginSh', { clear = true }),
    pattern = { 'sh', 'bash', 'zsh' },
    callback = load_ftplugin('sh'),
    desc = 'Load user ftplugin/sh.lua',
  })
  au('FileType', {
    group = gr('UserFtpluginLua', { clear = true }),
    pattern = 'lua',
    callback = load_ftplugin('lua'),
    desc = 'Load user ftplugin/lua.lua',
  })
  au('FileType', {
    group = gr('UserFtpluginYaml', { clear = true }),
    pattern = { 'yaml', 'yaml.ansible', 'yaml.docker-compose' },
    callback = load_ftplugin('yaml'),
    desc = 'Load user ftplugin/yaml.lua',
  })
  au('FileType', {
    group = gr('UserFtpluginPython', { clear = true }),
    pattern = 'python',
    callback = load_ftplugin('python'),
    desc = 'Load user ftplugin/python.lua',
  })
end

local function restore_cursor()
    au({"FileType"}, { buffer=0, once=true,
        callback = function()
            local types = {"nofile", "fugitive", "gitcommit", "gitrebase", "commit", "rebase", }
            if vim.fn.expand("%") == "" or types[vim.bo.filetype] ~= nil then
                return
            end
            local line = vim.fn.line
            if line([['"]]) > 0 and line([['"]]) <= line("$") then
                vim.api.nvim_command("normal! " .. [[g`"zv']])
            end
        end,
    })
end

au({'FocusGained','BufEnter','FileChangedShell','WinEnter'}, {command='checktime', group=main})
-- Disables automatic commenting on newline:
au({'Filetype'}, {
    pattern={'help', 'startuptime', 'qf', 'lspinfo'},
    command='nnoremap <buffer><silent> q :close<CR>',
    group=main})
au({"BufNewFile","BufRead"}, {
    group=main,
    pattern="**/systemd/**/*.service",
    callback=function() vim.bo.filetype="systemd" end})
-- Update binds when sxhkdrc is updated.
au({'BufWritePost'}, {pattern={'*sxhkdrc'}, command='!pkill -USR1 sxhkd', group=main})
au({'BufEnter'}, {command='set noreadonly', group=main})
au({'TermOpen'}, {pattern={'term://*'}, command='startinsert | setl nonumber | let &l:stl=" terminal %="', group=main})
au({'BufLeave'}, {pattern={'term://*'}, command='stopinsert', group=main})
au({"BufReadPost"}, {callback=restore_cursor, group=main, desc="auto line return"})
-- Clear search context when entering insert mode, which implicitly stops the
-- highlighting of whatever was searched for with hlsearch on. It should also
-- not be persisted between sessions.
au({'BufReadPre','FileReadPre'}, {command=[[let @/ = '']], group=mode_change})
au({'BufWritePost'}, {pattern='fonts.conf', command='!fc-cache', group=custom_updates})
au({'TextYankPost'}, {
    callback=function() vim.hl.on_yank{timeout=60, higroup="Search"} end,
    group=hi_yank})
au({'DirChanged'}, {pattern={'window','tab','tabpage','global'}, callback=function()
    vim.system({'zoxide', 'add', vim.fn.getcwd()}, { detach = true })
    end,group=main})
if true == false then
    au({'CursorHold','TextYankPost','FocusGained','FocusLost'}, {pattern={'*'}, command='if exists(":rshada") | rshada | wshada | endif', group=shada})
end
au({'BufWritePost'}, {pattern={'*'},
    callback=function()
        if string.match(vim.fn.getline(1), "^#!.*/bin/") then
            vim.system({'chmod', 'a+x', vim.fn.expand('<afile>')}, { detach = true })
        end
    end, group=utils})
au({'BufNewFile','BufWritePre'}, {pattern={'*'},
    command=[[if @% !~# '\(://\)' | call mkdir(expand('<afile>:p:h'), 'p') | endif]],
    group=utils
})

vim.g.markdown_fenced_languages={'shell=bash'}
vim.filetype.add({
  extension = { rasi = 'scss', ignore = 'gitignore', ojs = 'javascript', astro = 'astro', mdx = 'mdx' },
  filename = { ['flake.lock'] = 'json' },
})

-- Tune 'path' and 'suffixesadd' per filetype to reduce gf collisions
do
  local gfaug = gr('GfGlobalTuning', { clear = true })
  au({ 'BufEnter', 'BufNewFile' }, {
    group = gfaug,
    callback = function(args)
      -- Buffer-local guard: suffixesadd only needs to be set once per buffer.
      -- (suffixesadd is window-local but the extension is constant per file.)
      if vim.b[args.buf]._gf_suffixes_set then return end
      local name = vim.api.nvim_buf_get_name(args.buf)
      if not name or name == '' then return end
      local ext = vim.fn.fnamemodify(name, ':e')
      if not ext or ext == '' then return end
      local dotext = '.' .. ext
      local cur = vim.opt_local.suffixesadd:get()
      for _, s in ipairs(cur) do
        if s == dotext then
          vim.b[args.buf]._gf_suffixes_set = true
          return
        end
      end
      pcall(function() vim.opt_local.suffixesadd:prepend({ dotext }) end)
      vim.b[args.buf]._gf_suffixes_set = true
    end,
    desc = 'Prioritize current extension in suffixesadd',
  })

  local ft_preferred_dirs = {
    python = { 'src', 'tests' },
    lua = { 'lua', 'plugin' },
    javascript = { 'src', 'lib' },
    typescript = { 'src', 'lib' },
    javascriptreact = { 'src', 'lib', 'components' },
    typescriptreact = { 'src', 'lib', 'components' },
    rust = { 'src' },
    c = { 'src', 'include' },
    cpp = { 'src', 'include' },
    objc = { 'src', 'include' },
    objcpp = { 'src', 'include' },
    nix = { 'nix' },
    sh = { 'scripts', 'shell' },
    bash = { 'scripts', 'shell' },
    zsh = { 'scripts', 'shell' },
  }
  local function prepend_unique_path_dirs(dirs)
    if not dirs or vim.tbl_isempty(dirs) then return end
    local items = {}
    for _, d in ipairs(dirs) do table.insert(items, d); table.insert(items, d .. '/**') end
    local present = {}
    for _, p in ipairs(vim.opt_local.path:get()) do present[p] = true end
    for i = #items, 1, -1 do
      local it = items[i]
      if not present[it] then vim.opt_local.path:prepend(it); present[it] = true end
    end
  end
  au('FileType', {
    group = gfaug,
    callback = function(args)
      local ft = args.match or vim.bo[args.buf].filetype
      prepend_unique_path_dirs(ft_preferred_dirs[ft])
    end,
  })
end
