local function gh(repo) return 'https://github.com/' .. repo end

-- [[ LSP Configuration ]]

---@type table<string, vim.lsp.Config>
local servers = {
  stylua = {},
  yamlls = {},

  tofu_ls = {},
  ansiblels = {},
  docker_language_server = {},

  clangd = {},
  gopls = {},

  bashls = {},
  shellcheck = {},
  shfmt = {},

  tinymist = {
    settings = {
      formatterMode = 'typstyle',

      -- When to export is handled by the custom.plugins.typst
      -- exportPdf = '',
      outputPath = '$root/output/$dir/$name',
    },
  },

  prettierd = {},

  tailwindcss = {
    settings = {
      tailwindCSS = {
        experimental = {
          classRegex = {
            { 'cn\\(([^)]*)\\)', "'([^']*)'" },
            { 'cn\\(([^)]*)\\)', '"([^"]*)"' },
          },
        },
      },
    },
  },

  vtsls = {
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
      },
      typescript = {
        tsserver = {
          pluginPaths = {
            './node_modules',
          },
        },
        inlayHints = {
          parameterNames = {
            enabled = 'all',
          },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        },
      },
    },
  },

  svelte = {
    settings = {
      typescript = {
        inlayHints = {
          parameterNames = {
            enabled = 'none',
            suppressWhenArgumentMatchesName = true,
          },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = false },
          enumMemberValues = { enabled = true },
        },
      },
    },
  },

  -- Special Lua Config, as recommended by neovim help docs
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      end

      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = {
          version = 'LuaJIT',
          path = { 'lua/?.lua', 'lua/?/init.lua' },
        },
        workspace = {
          checkThirdParty = false,
          -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
          --  See https://github.com/neovim/nvim-lspconfig/issues/3189
          library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
            '${3rd}/luv/library',
            '${3rd}/busted/library',
          }),
        },
      })
    end,
    ---@type lspconfig.settings.lua_ls
    settings = {
      Lua = {
        format = { enable = false }, -- Disable formatting (formatting is done by stylua)
      },
    },
  },
}

-- Delete some ass built in lsp keymaps
local del = function(mode, keys) pcall(vim.keymap.del, mode, keys) end
del('n', 'gra')
del('n', 'gri')
del('n', 'grr')
del('n', 'grt')
del('n', 'grx')
del('n', 'grn')

-- Useful status updates for LSP.
vim.pack.add { gh 'j-hui/fidget.nvim' }
require('fidget').setup {}

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Rename the variable under your cursor.
    map('<leader>cr', function(args)
      local old_name = vim.fn.expand '<cword>'
      vim.ui.input({ default = old_name, prompt = 'Rename symbol' }, function(new_name)
        if new_name == nil then return end
        if new_name == '' then return end
        vim.lsp.buf.rename(new_name)
      end)
    end, '[R]ename')

    -- Execute a code action, usually your cursor needs to be on top of an error
    map('<leader>ca', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/documentHighlight', event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    if client and client:supports_method('textDocument/inlayHint', event.buf) then
      vim.lsp.inlay_hint.enable()
      map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')

      local orig_inlay_hint_handler = vim.lsp.inlay_hint.on_inlayhint

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.lsp.inlay_hint.on_inlayhint = function(err, result, ctx)
        local max_len = 15

        if result then
          for _, hint in ipairs(result) do
            local label = hint.label
            if type(label) == 'string' and #label > max_len then
              hint.label = string.sub(label, 1, max_len - 3) .. '...'
            elseif type(label) == 'table' then
              local current_len = 0
              local reached_max = false
              for _, part in ipairs(label) do
                if current_len + #part.value > max_len then
                  if not reached_max then
                    part.value = string.sub(part.value, 1, math.max(0, max_len - current_len - 3)) .. '...'
                  else
                    part.value = ''
                  end
                  reached_max = true
                end
                current_len = current_len + #part.value
              end
            end
          end
        end
        orig_inlay_hint_handler(err, result, ctx)
      end
    end
  end,
})

vim.pack.add {
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
}

-- Automatically install LSPs and related tools to stdpath for Neovim
require('mason').setup {}

vim.keymap.set('n', '<leader>cm', '<cmd>Mason<CR>', { desc = 'Open Mason' })

-- Ensure the servers and tools above are installed
local ensure_installed = vim.tbl_keys(servers or {})
vim.list_extend(ensure_installed, {
  -- You can add other tools here that you want Mason to install
})

require('mason-tool-installer').setup { ensure_installed = ensure_installed }

for name, server in pairs(servers) do
  vim.lsp.config(name, server)
  vim.lsp.enable(name)
end
