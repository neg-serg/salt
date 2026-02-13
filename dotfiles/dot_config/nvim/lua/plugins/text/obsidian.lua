-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ obsidian-nvim/obsidian.nvim                                                 │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'obsidian-nvim/obsidian.nvim', version='*', ft='markdown',
        dependencies={'nvim-lua/plenary.nvim'},
        config=function()
            local obsidian = require('obsidian')

            obsidian.setup({
                legacy_commands=false,
                workspaces={
                    {name='notes', path='~/notes'},
                },
                picker={name='fzf-lua'},

                note_id_func=function(title)
                    if title ~= nil then
                        return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower()
                    else
                        return tostring(os.date('%Y%m%d%H%M'))
                    end
                end,

                wiki_link_func='prepend_note_path',

                attachments={folder=''},
                ui={enable=false}, -- render-markdown.nvim handles rendering
                daily_notes={folder=''},
                templates={folder=''},
                search={sort_by='path', sort_reversed=false},
            })

            local function yank_notelink()
                local fname = vim.fn.expand('%:t:r')
                local link = '[[' .. fname .. ']]'
                vim.fn.setreg('+', link)
                vim.notify('Yanked: ' .. link)
            end

            local function browse_media()
                require('fzf-lua').files({
                    cwd=vim.fn.expand('~/notes'),
                    fd_opts='--type f -e png -e jpg -e jpeg -e gif -e svg -e webp -e mp4 -e webm -e pdf',
                })
            end

            local function set_obsidian_keys(buf)
                local opts={silent=true, noremap=true, buffer=buf}
                vim.keymap.set('i', '<leader>[', '<Cmd>Obsidian link<CR>', opts)
                vim.keymap.set('n', '<C-S-i>', '<Cmd>Obsidian paste_img<CR>', opts)
                vim.keymap.set('n', '<C-a>', '<Cmd>Obsidian tags<CR>', opts)
                vim.keymap.set('n', '<S-m>', browse_media, opts)
                vim.keymap.set('n', '<C-t>', '<Cmd>Obsidian toggle_checkbox<CR>', opts)
                vim.keymap.set('n', '<C-y>', yank_notelink, opts)
                vim.keymap.set('n', '<leader>b', '<Cmd>Obsidian backlinks<CR>', opts)
            end

            vim.api.nvim_create_autocmd({'BufNewFile','BufRead'}, {
                pattern='*.md',
                group=vim.api.nvim_create_augroup('obsidian_only_keymap', {clear=true}),
                callback=function(ev) set_obsidian_keys(ev.buf) end,
            })

            if vim.bo.filetype == 'markdown' then
                set_obsidian_keys(0)
            end
        end}
