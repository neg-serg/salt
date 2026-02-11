local M = {}

M.ignore_patterns = {
  '__pycache__/', '__pycache__/*',
  'build/', 'gradle/', 'node_modules/', 'node_modules/*',
  'smalljre_*/*', 'target/', 'vendor/*',
  '.dart_tool/', '.git/', '.github/', '.gradle/', '.idea/', '.vscode/',
  '%.sqlite3', '%.ipynb', '%.lock', '%.pdb', '%.dll', '%.class', '%.exe',
  '%.cache', '%.pdf', '%.dylib', '%.jar', '%.docx', '%.met', '%.burp',
  '%.mp4', '%.mkv', '%.rar', '%.zip', '%.7z', '%.tar', '%.bz2', '%.epub',
  '%.flac', '%.tar.gz',
}

function M.project_root()
  local cwd = vim.uv.cwd()
  for _, marker in ipairs({ '.git', '.hg', 'pyproject.toml', 'package.json', 'Cargo.toml', 'go.mod' }) do
    local p = vim.fn.finddir(marker, cwd .. ';'); if p ~= '' then return vim.fn.fnamemodify(p, ':h') end
    p = vim.fn.findfile(marker, cwd .. ';'); if p ~= '' then return vim.fn.fnamemodify(p, ':h') end
  end
  return cwd
end

function M.smart_files()
  local ok = pcall(require('fzf-lua').git_files, { show_untracked = true })
  if not ok then require('fzf-lua').files() end
end

function M.turbo_find(opts)
  opts = opts or {}
  require('fzf-lua').files({
    cwd = opts.cwd or vim.fn.expand('%:p:h'),
    fd_opts = '-H --ignore-vcs -d 2 --strip-cwd-prefix --type f',
    previewer = false,
  })
end

function M.qf_toggle()
  local winid = vim.fn.getqflist({ winid = 0 }).winid
  if winid ~= 0 then vim.cmd('cclose') else vim.cmd('copen') end
end

function M.qf_clear()
  vim.fn.setqflist({})
  vim.notify('Quickfix cleared')
end

function M.apply_cmd_to_qf(cmd)
  if not cmd or cmd == '' then return end
  vim.cmd('copen')
  vim.cmd('cdo ' .. cmd)
end

return M
