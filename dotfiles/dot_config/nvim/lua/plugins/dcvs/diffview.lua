-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ sindrets/diffview.nvim                                                       │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'sindrets/diffview.nvim', -- diff view for multiple files
    config=function()
        local actions = require("diffview.actions")

        require('diffview').setup {
            diff_binaries=false,
            enhanced_diff_hl=true,
            use_icons=true,
            icons={folder_closed="", folder_open=""},
            signs={fold_closed="", fold_open=""},
            file_panel={
                listing_style="tree",
                tree_options={
                    flatten_dirs=true,
                    folder_statuses="only_folded",
                },
                win_config={position="left", width=35},
            },
            file_history_panel={win_config={position="bottom", height=16}},
            default_args={
                DiffviewOpen={},
                DiffviewFileHistory={},
            },
            hooks={},
            view={
                default={layout="diff2_horizontal"},
                merge_tool={
                    layout="diff3_horizontal",
                    disable_diagnostics=true,
                },
                file_history={layout="diff2_horizontal"},
            },
            keymaps={
                view={
                    ["g<C-x>"]=actions.cycle_layout,
                    ["[x"]=actions.prev_conflict,
                    ["]x"]=actions.next_conflict,
                    ["<leader>co"]=actions.conflict_choose("ours"),
                    ["<leader>ct"]=actions.conflict_choose("theirs"),
                    ["<leader>cb"]=actions.conflict_choose("base"),
                    ["<leader>ca"]=actions.conflict_choose("all"),
                    ["dx"]=actions.conflict_choose("none"),
                },
                diff1={},
                diff2={},
                diff3={
                    {{"n","x"},"2do",actions.diffget("ours")},
                    {{"n","x"},"3do",actions.diffget("theirs")},
                },
                diff4={
                    {{"n","x"},"1do",actions.diffget("base")},
                    {{"n","x"},"2do",actions.diffget("ours")},
                    {{"n","x"},"3do",actions.diffget("theirs")},
                },
                file_panel={
                    ["g<C-x>"]=actions.cycle_layout,
                    ["[x"]=actions.prev_conflict,
                    ["]x"]=actions.next_conflict,
                },
                file_history_panel={
                    ["g<C-x>"]=actions.cycle_layout,
                },
            },
        }

    Map('n', '<C-S-g>', '<Cmd>DiffviewFileHistory<CR>', {desc='Diffview file history'})
    Map('n', '\\a', '<Cmd>DiffviewOpen<CR>', {desc='Diffview open'})
    Map('n', '\\c', '<Cmd>DiffviewClose<CR>', {desc='Diffview close'})
    Map('n', '\\r', '<Cmd>DiffviewRefresh<CR>', {desc='Diffview refresh'})
    Map('n', '\\f', '<Cmd>DiffviewToggleFiles<CR>', {desc='Diffview toggle files'})
    Map('n', '\\0', '<Cmd>DiffviewOpen HEAD<CR>', {desc='Diffview HEAD'})
    Map('n', '\\1', '<Cmd>DiffviewOpen HEAD^<CR>', {desc='Diffview HEAD^'})
    Map('n', '\\2', '<Cmd>DiffviewOpen HEAD^^<CR>', {desc='Diffview HEAD^^'})
    Map('n', '\\3', '<Cmd>DiffviewOpen HEAD^^^<CR>', {desc='Diffview HEAD^^^'})
    Map('n', '\\4', '<Cmd>DiffviewOpen HEAD^^^^<CR>', {desc='Diffview HEAD^^^^'})
    end,
    cmd={'DiffviewOpen','DiffviewFileHistory'},
    dependencies={'nvim-tree/nvim-web-devicons','nvim-lua/plenary.nvim'},
    keys={'<C-S-G>','\\a','\\c','\\r','\\f','\\0','\\1','\\2','\\3','\\4'}, lazy=true}
