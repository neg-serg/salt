-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ akinsho/toggleterm.nvim                                                      │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'akinsho/toggleterm.nvim', -- better way to toggle term
    config=function()
        require'toggleterm'.setup({
            size=10,
            hide_numbers=true,
            shade_filetypes={},
            shade_terminals=true,
            start_in_insert=true,
            persist_size=true,
            direction='horizontal',
            close_on_exit=true,
        })
        local Terminal=require('toggleterm.terminal').Terminal
        local navigator=Terminal:new({cmd='zsh', env={NEOVIM_TERMINAL=1}})
        vim.keymap.set('n', 'ei', function() navigator:toggle() end, {silent=true, desc='Toggle terminal'})
    end,
    keys={'ei'},
}
