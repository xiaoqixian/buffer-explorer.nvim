local Path = require("plenary.path")
local popup = require("plenary.popup")
local utils = require("buffer_explorer.utils")
local log = require("buffer_explorer.dev").log

local M = {}
local toggled = true

M.menu_winid = nil
M.menu_bufnr = nil

local config = {
  width = 60,
  height = 10,
  borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
}

local function create_window()
  log.trace("create_window()")

  local width = 60
  local height = 10

  if config then
    -- config supports absolute width and relative width
    if config.width then
      if config.width <= 1 then
        local gwidth = vim.api.nvim_list_uis()[1].width
        width = math.floor(gwidth * config.width)
      else 
        width = config.width
      end
    end

    if config.height then
      if config.height <= 1 then
        local gheight = vim.api.nvim_list_uis()[1].height
        height = math.floor(gheight * config.height)
      else 
        height = config.height
      end
    end

    local borderchars = config.borderchars
    -- this buf is not buflisted and not scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, false)

    local win_config = {
      title = "Buffers",
      line = math.floor(((vim.o.lines - height) / 2) - 1),
      col = math.floor((vim.o.columns - width) / 2),
      minwidth = width,
      minheight = height,
      borderchars = borderchars
    }

    local win_id, win = popup.create(bufnr, win_config)

    if config.highlight ~= "" then
      vim.api.nvim_set_option_value(
        "winhighlight",
        config.highlight,
        { win = win_id }
      )
    end

    if config.cursorline then
      vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
    end

    return {
      bufnr = bufnr,
      winid = win_id
    }
  end
end

local function buf_list_to_contents(buf_list)
  contents = {}
  for _, bufnr in ipairs(buf_list) do
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local buf_name = utils.normalize_path(file_path)
    table.insert(contents, " " .. buf_name)
  end
  return contents
end

function M.close_menu()
  assert(M.menu_winid)
  if M.menu_winid and vim.api.nvim_win_is_valid(M.menu_winid) then
    -- always force close
    vim.api.nvim_win_close(M.menu_winid, true)
  end
  M.menu_bufnr = nil
  M.menu_winid = nil
end

-- this function assume the menu window is created and is active.
local function refresh_menu(buf_list, cur_buf_line)
  local menu_lines = vim.api.nvim_buf_line_count(M.menu_bufnr)
  local contents = buf_list_to_contents(buf_list)
  local cursor_line = cur_buf_line or 1

  -- set buffer number for buffer-explorer window
  vim.api.nvim_set_option_value("number", true, { win = M.menu_winid })
  -- set extra window options in config
  if config.extra_win_options then
    for k, v in pairs(config.win_extra_options) do
      vim.api.nvim_set_option_value(k, v, { win = M.menu_winid })
    end
  end

  vim.api.nvim_buf_set_name(M.menu_bufnr, "buffer_explorer_menu")
  vim.api.nvim_buf_set_option(M.menu_bufnr, "filetype", "buffer_explorer")
  vim.api.nvim_buf_set_option(M.menu_bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(M.menu_bufnr, "bufhidden", "wipe")

  -- make the buffer temporarily writable to avoid warnings
  vim.api.nvim_buf_set_option(M.menu_bufnr, "readonly", false)
  vim.api.nvim_buf_set_lines(M.menu_bufnr, 0, menu_lines, false, contents)

  -- make the buffer not modifiable
  vim.api.nvim_buf_set_option(M.menu_bufnr, "modifiable", false)
  -- erase the buffer's modified mark to avoid trouble on exiting.
  vim.api.nvim_buf_set_option(M.menu_bufnr, "modified", false)

  vim.api.nvim_win_set_cursor(M.menu_winid, { cursor_line, 0 })
  --[[ vim.cmd(string.format(":call cursor(%d, %d)", cursor_line, 1)) ]]
end

function M.show_menu(buf_list)
  if M.menu_winid and vim.api.nvim_win_is_valid(M.menu_winid) then
    vim.api.nvim_win_close(M.menu_winid, true)
  end

  -- the bufnr that was before this function is called
  local cur_bufnr = vim.fn.bufnr()
  local cur_buf_line = 1
  for i, nr in ipairs(buf_list) do
    if nr == cur_bufnr then
      cur_buf_line = i
      break
    end
  end

  local win_info = create_window()
  M.menu_winid = win_info.winid
  M.menu_bufnr = win_info.bufnr

  refresh_menu(buf_list, cur_buf_line)
end

function M.setup(ui_config)
  if ui_config and type(ui_config) == "table" then
    for k, v in pairs(ui_config) do
      config[k] = v
    end
  end
end

return M
