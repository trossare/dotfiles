--- @generic T
---@param buf integer
---@param callback fun(client: vim.lsp.Client): T?
local function apply_to_lsp_client(buf, callback)
  local clients = vim.lsp.get_clients {
    name = 'tinymist',
    bufnr = buf,
  }

  if #clients == 0 then return end
  local client = clients[1]
  return callback(client)
end

---@param buf integer
---@param callback fun(err: lsp.ResponseError?, result: { data: vim.NIL, path: string }?)
local function typst_export_pdf(buf, callback)
  apply_to_lsp_client(buf, function(client)
    client:exec_cmd({
      title = 'Export PDF',
      command = 'tinymist.exportPdf',
      arguments = {
        vim.api.nvim_buf_get_name(buf),
      },
    }, { bufnr = buf }, function(err, result)
      if err then
        callback(err, nil)
      else
        callback(nil, result)
      end
    end)
  end)

  return 0
end

--- @param buf integer
--- @param method 'never' | 'onSave' | 'onType'
--- @param toggle boolean?
local function set_export_pdf_method(buf, method, toggle)
  return apply_to_lsp_client(buf, function(client)
    client.config.settings = client.config.settings or {}
    toggle = toggle or false
    if toggle and client.config.settings.exportPdf == method then
      client.config.settings.exportPdf = 'never'
    else
      client.config.settings.exportPdf = method
    end
    client:notify('workspace/didChangeConfiguration', {
      settings = client.config.settings,
    })
    return client.config.settings.exportPdf
  end)
end

--- @param buf integer
local function get_document_metrics(buf)
  return apply_to_lsp_client(buf, function(client)
    -- client:exec_cmd({
    --   title = 'Get document metrics',
    --   command = 'tinymist.com',
    --   arguments = { 'file://' .. vim.api.nvim_buf_get_name(buf) },
    -- }, {
    --   bufnr = buf,
    -- }, function(err, result) print(vim.inspect(result)) end)
    client:request('workspace/diagnostic', {}, function(err, result) print(vim.inspect(err, result)) end)
  end)
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('typst-filetype', { clear = true }),
  pattern = 'typst',
  callback = function(event)
    vim.keymap.set('n', '<leader>cct', function()
      local method = set_export_pdf_method(event.buf, 'onType', true)
      print('Changed exportPdf method to "' .. method .. '"')
    end, { desc = 'Toggle export on type' })

    vim.keymap.set('n', '<leader>ccw', function()
      local document_metrics = get_document_metrics(event.buf)
      -- print('Metrics: "' .. document_metrics .. '"')
    end, { desc = 'Get document metrics' })

    vim.keymap.set('n', '<leader>cco', function()
      local result = typst_export_pdf(event.buf, function(err, result)
        if err ~= nil then
          vim.notify('lsp error: ' .. err.message)
          return
        end

        if result == nil then
          vim.notify 'could not get export pdf result'
        else
          set_export_pdf_method(event.buf, 'onType', false)
          vim.fn.jobstart({ 'zathura', result.path }, {
            detach = false,
            on_exit = function() set_export_pdf_method(event.buf, 'never') end,
          })
        end
      end)

      if result == nil then
        vim.notify 'could not get tinymist lsp client'
        return
      end
    end, { buf = event.buf, desc = 'Open pdf' })

    vim.keymap.set('n', '<leader>cce', function()
      local result = typst_export_pdf(event.buf, function(err, result)
        if err ~= nil then
          vim.notify('lsp error: ' .. err.message)
          return
        end
        if result == nil then
          vim.notify 'could not get export pdf result'
        else
          vim.notify 'exported pdf'
        end
      end)

      if result == nil then
        vim.notify 'Could not get tinymist lsp client'
        return
      end
    end, { buf = event.buf, desc = 'Export pdf' })
  end,
})
