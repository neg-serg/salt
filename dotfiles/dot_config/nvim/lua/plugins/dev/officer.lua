-- ┌───────────────────────────────────────────────────────────────────────────────────┐
-- │ █▓▒░ pianocomposer321/officer.nvim                                                │
-- └───────────────────────────────────────────────────────────────────────────────────┘
return {'pianocomposer321/officer.nvim',
    dependencies = 'stevearc/overseer.nvim',
    event = 'VeryLazy',
    config = function()
        require('officer').setup{}
    end
}
