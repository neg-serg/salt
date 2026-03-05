-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ grddavies/tidal.nvim                                                        │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {
    'grddavies/tidal.nvim',
    ft = 'tidal',
    opts = {
        boot = {
            tidal = {
                file = '/usr/share/haskell-tidal/BootTidal.hs',
            },
            sclang = { enabled = true },
        },
    },
}
