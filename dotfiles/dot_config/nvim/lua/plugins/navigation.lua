-- Navigation plugins: leap, flit, harpoon, namu, vim-asterisk
return {
  -- │ █▓▒░ andyg/leap.nvim                                                          │
  {url = 'https://codeberg.org/andyg/leap.nvim',
    config=function()
      require'leap'.opts = {
        max_phase_one_targets = nil,
        highlight_unlabeled_phase_one_targets = false,
        max_highlighted_traversal_targets = 10,
        case_sensitive = false,
        equivalence_classes = { ' \t\r\n', },
        substitute_chars = {},
        safe_labels = {
          "s", "f", "n", "u", "t", "/",
          "S", "F", "N", "L", "H", "M", "U", "G", "T", "?", "Z"
        },
        labels = {
          "s", "f", "n",
          "j", "k", "l", "h", "o", "d", "w", "e", "m", "b",
          "u", "y", "v", "r", "g", "t", "c", "x", "/", "z",
          "S", "F", "N",
          "J", "K", "L", "H", "O", "D", "W", "E", "M", "B",
          "U", "Y", "V", "R", "G", "T", "C", "X", "?", "Z"
        },
        special_keys = {
          repeat_search = '<enter>',
          next_phase_one_target = '<enter>',
          next_target = {'<enter>', ';'},
          prev_target = {'<tab>', ','},
          next_group = '<space>',
          prev_group = '<tab>',
          multi_accept = '<enter>',
          multi_revert = '<backspace>',
        },
      }
    end,
    keys = {
      { 's', '<Plug>(leap-anywhere)', mode = 'n' },
      { 's', '<Plug>(leap-forward)', mode = 'o' },
      { 'S', '<Plug>(leap-backward)', mode = 'o' },
      { 'gs', function () require('leap.remote').action() end, mode = {'n', 'x', 'o'} },
    }
  },

  -- │ █▓▒░ ggandor/flit.nvim                                                        │
  {
    'ggandor/flit.nvim',
    dependencies = { {url = 'https://codeberg.org/andyg/leap.nvim'} },
    keys = {
      { 'f', mode = { 'n', 'x', 'o' }, desc = 'Flit f' },
      { 'F', mode = { 'n', 'x', 'o' }, desc = 'Flit F' },
      { 't', mode = { 'n', 'x', 'o' }, desc = 'Flit t' },
      { 'T', mode = { 'n', 'x', 'o' }, desc = 'Flit T' },
    },
    opts = {
      labeled_modes = 'nv',
      multiline = true,
    },
  },

  -- │ █▓▒░ ThePrimeagen/harpoon                                                     │
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    main = "harpoon",
    opts = {},
    keys = {
      { "<leader>A", function() require("harpoon"):list():add() end, desc = "Harpoon add" },
      { "<C-e>", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon menu" },
      { "<C-h>", function() require("harpoon"):list():select(1) end, desc = "Harpoon 1" },
      { "<C-j>", function() require("harpoon"):list():select(2) end, desc = "Harpoon 2" },
      { "<C-n>", function() require("harpoon"):list():select(3) end, desc = "Harpoon 3" },
      { "<C-s>", function() require("harpoon"):list():select(4) end, desc = "Harpoon 4" },
      { "<C-S-P>", function() require("harpoon"):list():prev() end, desc = "Harpoon prev" },
      { "<C-S-N>", function() require("harpoon"):list():next() end, desc = "Harpoon next" },
    },
  },

  -- │ █▓▒░ bassamsdata/namu.nvim                                                    │
  {
    'bassamsdata/namu.nvim',
    cmd = { 'Namu' },
    opts = {
      namu_symbols = { enable = true, options = {} },
    },
    keys = {
      { '<leader>ns', '<cmd>Namu symbols<cr>',    desc = '[Namu] Symbols (buffer)' },
      { '<leader>nw', '<cmd>Namu workspace<cr>',  desc = '[Namu] Symbols (workspace)' },
      { '<leader>nd', '<cmd>Namu diagnostics<cr>', desc = '[Namu] Diagnostics' },
      { '<leader>nh', '<cmd>Namu help<cr>',       desc = '[Namu] Help' },
    },
  },

  -- │ █▓▒░ haya14busa/vim-asterisk                                                  │
  {'haya14busa/vim-asterisk',
    keys = {
      { "*", "<Plug>(asterisk-#)", mode = "n" },
      { "#", "<Plug>(asterisk-*)", mode = "n" },
      { "g*", "<Plug>(asterisk-g#)", mode = "n" },
      { "g#", "<Plug>(asterisk-g*)", mode = "n" },
      { "z*", "<Plug>(asterisk-z#)", mode = "n" },
      { "gz*", "<Plug>(asterisk-gz#)", mode = "n" },
      { "z#", "<Plug>(asterisk-z*)", mode = "n" },
      { "gz#", "<Plug>(asterisk-gz*)", mode = "n" },
    },
  },
}
