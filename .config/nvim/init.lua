-- ============================================================
-- SECTION 1: OPTIONS
-- Core Neovim settings, leaders, options, basic keymaps, basic autocmds
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  -- Set <space> as the leader key
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in the terminal
  vim.g.have_nerd_font = true

  -- [[ Setting options ]]
  -- Line numbers and relative numbers
  vim.o.number = true
  vim.o.relativenumber = true

  vim.o.wrap = false

  -- Enable mouse mode in all modes
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false

  -- Sync clipboard between OS and Neovim.
  -- vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  -- Enable break indent
  vim.o.breakindent = true

  -- Enable undo/redo changes even after closing and reopening a file
  vim.o.undofile = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  vim.o.list = true
  vim.opt.listchars = { tab = '- ', trail = '·', nbsp = '␣' }

  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 10

  -- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
  -- instead raise a dialog asking if you wish to save the current file(s)
  vim.o.confirm = true

  vim.o.tabstop = 2
  vim.o.shiftwidth = 2
  vim.o.expandtab = true

  vim.filetype.add {
    filename = {
      ['docker-compose.yml'] = 'yaml.docker-compose',
      ['docker-compose.yaml'] = 'yaml.docker-compose',
      ['compose.yml'] = 'yaml.docker-compose',
      ['compose.yaml'] = 'yaml.docker-compose',
    },
    extension = {
      tf = 'opentofu',
      tfvars = 'opentofu-vars',
      tofu = 'opentofu',
    },
  }
end

-- ============================================================
-- SECTION 2: KEYMAPS
-- basic keymaps
-- ============================================================
do
  -- [[ Basic Keymaps ]]

  -- Config keybinds
  vim.keymap.set('n', '<leader>Cs', function()
    local config_path = vim.fn.stdpath 'config' .. '/init.lua'
    if vim.api.nvim_buf_get_name(0) == config_path then vim.cmd 'w' end
    vim.cmd('source ' .. config_path)
  end, { desc = 'Soruce init.lua' })

  vim.keymap.set('n', '<leader>Ct', '<cmd>Telescope colorscheme a<CR>', { desc = 'Change colorscheme' })

  -- Change macro keybind so I don't accidentally press it all the time
  vim.keymap.set('n', 'Q', 'q')
  vim.keymap.set('n', 'q', '<Nop>')

  -- Tab
  vim.keymap.set('n', 'H', '<cmd>bprevious<CR>')
  vim.keymap.set('n', 'L', '<cmd>bnext<CR>')
  vim.keymap.set('n', '<A-h>', '<cmd>bprevious<CR>')
  vim.keymap.set('n', '<A-l>', '<cmd>bnext<CR>')

  -- Indent
  vim.keymap.set('v', '>', '>gv')
  vim.keymap.set('v', '<', '<gv')

  -- Window splitting
  vim.keymap.set('n', '<leader>|', '<cmd>vsplit<CR>', { desc = 'Split window vertically' })
  vim.keymap.set('n', '<leader>-', '<cmd>split<CR>', { desc = 'Split window horizontally' })

  -- Window resizing
  vim.keymap.set('n', '<C-up>', '<C-w>+')
  vim.keymap.set('n', '<C-down>', '<C-w>-')
  vim.keymap.set('n', '<C-left>', '<C-w><')
  vim.keymap.set('n', '<C-right>', '<C-w>>')

  -- Paste
  vim.keymap.set('v', 'p', '"_dP', { desc = 'Paste without overwriting register' })

  -- System clipboard
  vim.keymap.set({ 'n', 'v' }, '<leader>y', '"+y', { desc = 'Yank to clipboard' })
  vim.keymap.set({ 'n', 'v' }, '<leader>p', '"+p', { desc = 'Paste from clipboard' })
  vim.keymap.set({ 'n', 'v' }, '<leader>d', '"+d', { desc = 'Delete to clipboard' })

  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = true,

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  ---@param lhs string
  ---@param count integer
  ---@param severity vim.diagnostic.Severity
  local function set_jump_diag_keymap(lhs, count, severity)
    vim.keymap.set('n', lhs, function()
      vim.diagnostic.jump {
        count = count,
        severity = severity,
      }
    end)
  end

  set_jump_diag_keymap(']w', 1, vim.diagnostic.severity.WARN)
  set_jump_diag_keymap('[w', -1, vim.diagnostic.severity.WARN)
  set_jump_diag_keymap(']e', 1, vim.diagnostic.severity.ERROR)
  set_jump_diag_keymap('[e', -1, vim.diagnostic.severity.ERROR)

  vim.keymap.set('n', '<leader>qq', function()
    local qf = vim.fn.getqflist { winid = 0 }
    if qf.winid == 0 then
      vim.cmd 'copen'
    else
      vim.cmd 'cclose'
    end
  end, { desc = 'Toggle Quickfix list' })

  vim.keymap.set('n', '<leader>qd', function() vim.diagnostic.setqflist() end, { desc = 'Open Quickfix list with Diagnostics' })

  vim.keymap.set(
    'n',
    '<leader>qw',
    function() vim.diagnostic.setqflist { severity = { min = vim.diagnostic.severity.WARN } } end,
    { desc = 'Open Quickfix list with Warnings' }
  )

  vim.keymap.set(
    'n',
    '<leader>qe',
    function() vim.diagnostic.setqflist { severity = vim.diagnostic.severity.ERROR } end,
    { desc = 'Open Quickfix list with Errors' }
  )

  -- Terminal
  local float_term = require 'custom.plugins.float_term'

  local open_shell = float_term.create(vim.o.shell, 0.9, { 't', '<C-_>' })

  vim.keymap.set('n', '<C-_>', open_shell, { desc = 'Open terminal' })
  vim.keymap.set('n', '<leader>ct', open_shell, { desc = 'Open terminal' })
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
  vim.keymap.set('t', '<Esc>q', '<C-\\><C-n><C-w>q', { desc = 'Close terminal' })

  -- Git
  local open_lazygit = float_term.create('lazygit', 0.9)
  local open_lazygit_dotfiles = float_term.create('lazygit -g $HOME/.dotfiles -w $HOME', 0.9)

  vim.keymap.set('n', '<leader>gg', function()
    local cwd = vim.fn.getcwd()
    local config = vim.fn.stdpath 'config'
    if cwd == config or vim.startswith(cwd, config .. '/') then
      open_lazygit_dotfiles()
    else
      open_lazygit()
    end
  end, { desc = 'Lazygit' })
  vim.keymap.set('n', '<leader>gd', open_lazygit_dotfiles, { desc = 'Lazygit dotfiles' })

  vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Keybinds to make split navigation easier.
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Jump rempas
  vim.keymap.set('n', 'ö', '[', { remap = true })
  vim.keymap.set('n', 'ä', ']', { remap = true })

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  local ft_group = vim.api.nvim_create_augroup('FileTypeSettings', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = ft_group,
    pattern = { 'cpp' },
    callback = function()
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = ft_group,
    pattern = { 'javascript', 'typescript', 'svelte' },
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
    end,
  })

  -- Move help window to the right
  vim.api.nvim_create_autocmd('FileType', {
    group = ft_group,
    pattern = 'help',
    callback = function()
      vim.cmd 'wincmd L'
      vim.cmd 'vertical resize 80'
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = ft_group,
    pattern = { 'opentofu', 'opentofu-vars' },
    callback = function()
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.commentstring = '# %s'
    end,
  })
end

-- ============================================================
-- SECTION 3: PLUGIN MANAGER INTRO
-- vim.pack intro, build hooks
-- ============================================================
do
  -- [[ Intro to `vim.pack` ]]
  -- `vim.pack` is a new plugin manager built into Neovim,
  --  which provides a Lua interface for installing and managing plugins.
  --
  --  See `:help vim.pack`, `:help vim.pack-examples` or the
  --  excellent blog post from the creator of vim.pack and mini.nvim:
  --  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
  --
  --  To inspect plugin state and pending updates, run
  --    :lua vim.pack.update(nil, { offline = true })
  --
  --  To update plugins, run
  --    :lua vim.pack.update()
  --
  --
  --  Throughout the rest of the config there will be examples
  --  of how to install and configure plugins using `vim.pack`.
  --
  --  In this section we set up some autocommands to run build
  --  steps for certain plugins after they are installed or updated.

  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- This autocommand runs after a plugin is installed or updated and
  --  runs the appropriate build command for that plugin if necessary.
  --
  -- See `:help vim.pack-events`
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end
    end,
  })
end

---Because most plugins are hosted on GitHub, you can use the helper
---function to have less repetition in the following sections.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 4: UI / CORE UX PLUGINS
-- guess-indent, gitsigns, which-key, colorscheme, todo-comments, mini modules
-- ============================================================
do
  -- [[ Installing and Configuring Plugins ]]
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {}

  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  require('gitsigns').setup {
    signs = {
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
    },
  }

  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    -- Document existing key chains
    spec = {
      { '<leader>C', group = '[C]onfig', mode = { 'n' } },
      { '<leader>c', group = '[C]ode', mode = { 'n' } },
      { '<leader>cc', group = 'Language keymaps', mode = { 'n' } },
      { '<leader>g', group = '[G]it', mode = { 'n' } },
      { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
      { '<leader>b', group = '[B]uffer', mode = { 'n' } },
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }

  -- [[ Colorscheme ]]
  vim.pack.add { gh 'folke/tokyonight.nvim' }
  ---@diagnostic disable-next-line: missing-fields
  require('tokyonight').setup {
    styles = {
      comments = { italic = false }, -- Disable italics in comments
    },
  }

  -- vim.cmd.colorscheme 'tokyonight-moon'
  vim.cmd.colorscheme 'tokyonight-night'

  vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', {
    underline = false,
    undercurl = false,
  })

  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- If a nerd font is available, load the icons module for pretty icons in various plugins.
  if vim.g.have_nerd_font then
    require('mini.icons').setup()
    -- Used for backwards compatibility with plugins that require `nvim-web-devicons` (e.g. telescope.nvim)
    MiniIcons.mock_nvim_web_devicons()
  end

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  require('mini.ai').setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Simple and easy statusline.
  local statusline = require 'mini.statusline'
  statusline.setup { use_icons = vim.g.have_nerd_font }

  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  require('mini.tabline').setup()

  local fts_that_are_not_allowed_on_the_tabline = { 'qf', 'man' }
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local ft = vim.bo[args.buf].filetype

      local is_ft_that_should_not_be_on_the_tabline = false
      for _, v in ipairs(fts_that_are_not_allowed_on_the_tabline) do
        if v == ft then
          is_ft_that_should_not_be_on_the_tabline = true
          break
        end
      end

      if is_ft_that_should_not_be_on_the_tabline then vim.bo[args.buf].buflisted = false end
    end,
  })

  -- Buffer
  require('mini.bufremove').setup()
  vim.keymap.set('n', '<leader>bd', MiniBufremove.delete, { desc = 'Delete current buffer' })
  vim.keymap.set('n', '<leader>bw', MiniBufremove.wipeout, { desc = 'Wipeout current buffer' })

  --- @param should_delete fun(integer): boolean
  local function delete_buffers(should_delete)
    local buffers = vim.api.nvim_list_bufs()
    for _, buf in ipairs(buffers) do
      local deleting = vim.bo[buf].buflisted and vim.bo[buf].buftype == ''
      deleting = deleting and should_delete(buf)
      if deleting then MiniBufremove.delete(buf) end
    end
  end

  vim.keymap.set('n', '<leader>bo', function()
    local current = vim.api.nvim_get_current_buf()
    delete_buffers(function(buf) return current ~= buf end)
  end, { desc = 'Delete other buffers' })

  vim.keymap.set('n', '<leader>bl', function()
    local current = vim.api.nvim_get_current_buf()
    delete_buffers(function(buf) return buf < current end)
  end, { desc = 'Delete left buffers' })

  vim.keymap.set('n', '<leader>br', function()
    local current = vim.api.nvim_get_current_buf()
    delete_buffers(function(buf) return current < buf end)
  end, { desc = 'Delete right buffers' })

  -- Sessions
  require('mini.sessions').setup { file = '' }

  vim.opt.sessionoptions:remove 'blank'

  local function get_session_name() return vim.fn.getcwd():gsub('[\\/:]+', '%%') end

  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      if vim.fn.argc() ~= 0 then return end

      vim.keymap.set('n', 's', function()
        local session = MiniSessions.detected[get_session_name()]
        if session ~= nil then
          MiniSessions.read(session.name)
        else
          vim.notify 'No session found'
        end
      end, {
        buffer = 0,
        silent = true,
      })
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if vim.fn.argc() ~= 0 then return end
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if require('custom.plugins.bufhelper').is_good_buf(buf) then
          MiniSessions.write(get_session_name(), {})
          break
        end
      end
    end,
  })
end

-- ============================================================
-- SECTION 5: SEARCH & NAVIGATION
-- Telescope setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- [[ Fuzzy Finder (files, lsp, etc) ]]
  --
  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

  vim.pack.add(telescope_plugins)

  local actions = require 'telescope.actions'
  require('telescope').setup {
    defaults = {
      mappings = {
        -- i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        n = {
          ['l'] = actions.select_default,
          ['q'] = actions.close,
        },
      },
    },
    pickers = {
      lsp_references = {
        file_ignore_patterns = {
          '/%.',
        },
      },
    },
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  -- Enable Telescope extensions if they are installed
  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')

  -- See `:help telescope.builtin`
  local builtin = require 'telescope.builtin'
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[S]earch [B]uffers' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = '[ ] Find files' })

  -- Add Telescope-based LSP pickers when an LSP attaches to a buffer.
  -- If you later switch picker plugins, this is where to update these mappings.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf

      -- Find references for the word under your cursor.
      vim.keymap.set('n', 'gr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

      -- Jump to the type of the word under your cursor.
      vim.keymap.set('n', 'gy', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto T[y]pe Definition' })

      -- Jump to the definition of the word under your cursor.
      vim.keymap.set('n', 'gd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

      -- vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

      -- Fuzzy find all the symbols in your current document.
      -- Symbols are things like variables, functions, types, etc.
      -- vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

      -- Fuzzy find all the symbols in your current workspace.
      -- Similar to document symbols, except searches over your entire project.
      -- vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
    end,
  })

  -- Override default behavior and theme when searching
  vim.keymap.set('n', '<leader>/', builtin.live_grep, { desc = '[/] Live grep!' })

  -- It's also possible to pass additional configuration options.
  --  See `:help telescope.builtin.live_grep()` for information about particular keys
  vim.keymap.set(
    'n',
    '<leader>s/',
    function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end,
    { desc = '[S]earch [/] in Open Files' }
  )

  -- Shortcut for searching your Neovim configuration files
  vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config', follow = true } end, { desc = '[S]earch [N]eovim files' })
end

-- ============================================================
-- SECTION 6: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
  require 'custom.lsp'
end

-- ============================================================
-- SECTION 7: FORMATTING
-- conform.nvim setup and keymap
-- ============================================================
do
  -- [[ Formatting ]]
  vim.pack.add { gh 'stevearc/conform.nvim' }
  require('conform').setup {
    notify_on_error = true,
    format_on_save = function(bufnr)
      -- You can specify filetypes to autoformat on save here:
      local enabled_filetypes = {
        lua = true,
        typescript = true,
        svelte = true,
        -- python = true,
      }
      if enabled_filetypes[vim.bo[bufnr].filetype] then
        return { timeout_ms = 500 }
      else
        return nil
      end
    end,
    default_format_opts = {
      lsp_format = 'fallback',
    },

    formatters_by_ft = {
      lua = { 'stylua' },
      typescript = { 'prettierd' },
      svelte = { 'prettierd' },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
end

-- ============================================================
-- SECTION 8: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  -- `friendly-snippets` contains a variety of premade snippets.
  --    See the README about individual language/framework/plugin snippets:
  --    https://github.com/rafamadriz/friendly-snippets
  --
  -- vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  -- require('luasnip.loaders.from_vscode').lazy_load()

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      preset = 'enter',
    },

    appearance = {
      nerd_font_variant = 'mono',
    },

    completion = {
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
      accept = { resolve_timeout_ms = 2000 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    fuzzy = { implementation = 'rust' },

    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 9: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --
  --  See `:help nvim-treesitter-intro`

  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end
    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds
    -- For more info on folds see `:help folds`
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Check if treesitter indentation is available for this language, and if so enable it
    -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

    -- Enable treesitter based indentation
    if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 10: OPTIONAL EXAMPLES / NEXT STEPS
-- kickstart.plugins.* examples
-- ============================================================
do
  -- require 'kickstart.plugins.debug'
  -- require 'kickstart.plugins.indent_line'
  -- require 'kickstart.plugins.lint'
  -- require 'kickstart.plugins.autopairs'
  -- require 'kickstart.plugins.gitsigns' -- adds gitsigns recommended keymaps

  require 'kickstart.plugins.neo-tree'

  -- Custom plugins (custom plugins)
  require 'custom.plugins'
  require('custom.plugins.ui').setup()
end
-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
