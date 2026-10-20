local M = {}

local id_counter = 0

---@type {[integer]: integer}
local bufs = {}

vim.api.nvim_create_autocmd('ExitPre', {
  callback = function()
    print 'exit'
    for _, buf in pairs(bufs) do
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end
  end,
})

local function generate_id()
  local id = id_counter
  id_counter = id_counter + 1
  return id
end

---@param id integer
---@return integer, boolean
local function get_buf(id)
  local buf = bufs[id]
  local needs_setup = false

  if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, false)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    bufs[id] = buf
    needs_setup = true
  end

  return buf, needs_setup
end

local function create_backdrop()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_hl(0, 'TerminalBackdrop', {
    bg = '#000000',
  })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = 'minimal',
    focusable = false,
    zindex = 40,
  })

  vim.api.nvim_set_option_value('winhl', 'Normal:TerminalBackdrop', { win = win })

  vim.api.nvim_set_option_value('winblend', 40, {
    win = win,
  })

  return win
end

local function close_window(win)
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, false) end
end

---@class CreateOpts
---@field close_keymaps string[] | nil

---@param cmd string
---@param size number
---@param opts? CreateOpts
---@return function
M.create = function(cmd, size, opts)
  local id = generate_id()
  opts = opts or {}

  local close_keymaps = { { 'n', 'q' } }
  if opts.close_keymaps ~= nil then table.insert(close_keymaps, opts.close_keymaps) end

  return function()
    local buf, needs_setup = get_buf(id)

    local backdrop_win = create_backdrop()

    local editor_width = vim.o.columns
    local editor_height = vim.o.lines
    local width = math.floor(editor_width * size)
    local height = math.floor(editor_height * size)
    local col = math.floor((editor_width - width) / 2)
    local row = math.floor((editor_height - height) / 2)

    local terminal_win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      border = 'rounded',
      style = 'minimal',
      zindex = 50,
    })

    if needs_setup then
      vim.api.nvim_win_call(terminal_win, function()
        vim.fn.jobstart(cmd, {
          term = true,
          pty = true,
          on_exit = function()
            close_window(terminal_win)
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
          end,
        })
      end)
    end

    vim.api.nvim_create_autocmd('WinLeave', {
      buf = buf,
      once = true,
      callback = function()
        vim.schedule(function() close_window(terminal_win) end)
      end,
    })

    vim.api.nvim_create_autocmd('WinClosed', {
      pattern = tostring(terminal_win),
      once = true,
      callback = function() close_window(backdrop_win) end,
    })

    for _, keymap in ipairs(close_keymaps) do
      local mode = keymap[1]
      local lhs = keymap[2]
      if mode == nil or lhs == nil then
        print('Failed to parse keymap: ' .. mode .. ' ' .. lhs)
      else
        vim.keymap.set(keymap[1], keymap[2], function() close_window(terminal_win) end, { buffer = buf, desc = 'Close terminal window' })
      end
    end

    vim.cmd.startinsert()

    return terminal_win
  end
end

return M
