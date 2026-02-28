-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ lewis6991/gitsigns.nvim                                                      │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'lewis6991/gitsigns.nvim', -- fast git decorations
    config=function()
        require('gitsigns').setup {
            on_attach = function(bufnr)
                local gs = require('gitsigns')
                local function bmap(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end
                bmap('n', '<leader>b', gs.preview_hunk, 'Git: preview hunk')
                bmap('n', '<leader>q', function() gs.blame_line({full=true}) end, 'Git: blame line (full)')
                bmap('n', '<leader>gB', gs.blame_line, 'Git: blame line')
                bmap('n', '<leader>g]', gs.next_hunk, 'Git: next hunk')
                bmap('n', '<leader>g[', gs.prev_hunk, 'Git: prev hunk')
                bmap('n', '<leader>g?', gs.preview_hunk, 'Git: preview hunk')
            end,
            signs={
                add={text='▎', show_count=false},
                change={text='▎', show_count=false},
                delete={text='_', show_count=false},
                topdelete={text='‾', show_count=false},
                changedelete={text='~', show_count=false},
            },
            count_chars={
                [1]  ="",   [2]="₂",  [3]="₃",
                [4]  ="₄",  [5]="₅",  [6]="₆",
                [7]  ="₇",  [8]="₈",  [9]="₉",
                ["+"]="₊",
            },
            linehl=false,
            numhl=false,
            signcolumn=true,
            word_diff=false,
            watch_gitdir={interval=500, follow_files=true},
            sign_priority=6,
            update_debounce=100,
            max_file_length=40000,
            diff_opts={ algorithm="patience", internal=true, indent_heuristic=true },
            attach_to_untracked=true,
            current_line_blame=false,
            current_line_blame_opts={
                virt_text=true,
                virt_text_pos='eol',
                delay=1000,
                ignore_whitespace=false,
            },
        }
    end,
    event={'BufReadPost','BufNewFile'}}
