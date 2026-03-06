-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ grddavies/tidal.nvim                                                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
    'grddavies/tidal.nvim',
    event = { 'BufRead *.tidal', 'BufNewFile *.tidal' },
    keys = {
        { '<C-CR>', '<Cmd>TidalLaunch<CR>', ft = 'haskell', desc = 'Launch Tidal + SuperDirt' },
        { '<C-S-CR>', '<Cmd>TidalQuit<CR>', ft = 'haskell', desc = 'Quit Tidal' },
    },
    opts = {
        boot = {
            tidal = {
                file = '/usr/share/haskell-tidal/BootTidal.hs',
            },
            sclang = { enabled = true },
        },
    },
}
