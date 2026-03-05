-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ grddavies/tidal.nvim                                                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
    'grddavies/tidal.nvim',
    event = { 'BufRead *.tidal', 'BufNewFile *.tidal' },
    opts = {
        boot = {
            tidal = {
                file = '/usr/share/haskell-tidal/BootTidal.hs',
            },
            sclang = { enabled = true },
        },
    },
}
