local Path = require("plenary.path")

local utils = {}

function utils.can_buf_deleted(bufnr, buf_name)
  return (
    vim.api.nvim_buf_is_valid(bufnr) and
    not buf_name:match("^term://.*") and
    not vim.bo[bufnr].modified       and
    burnr ~= -1
  )
end

function utils.project_key()
  return vim.loop.cwd()
end

function utils.normalize_path(item)
  if string.find(item, ".*:///.*") ~= nil then
      return Path:new(item)
  end
  return Path:new(Path:new(item):absolute()):make_relative(utils.project_key())
end

function utils.get_file_name(file)
  return file:match("[^/\\]*$")
end


local function key_in_table(key, table)
  for k, _ in pairs(table) do
    if k == key then
      return true
    end
  end
  return false
end


function utils.get_short_file_name(file, current_short_fns)
  local short_name = nil
  -- Get normalized file path
  file = utils.normalize_path(file)
  -- Get all folders in the file path
  local folders = {}
  -- Convert file to string
  local file_str = tostring(file)
  for folder in string.gmatch(file_str, "([^/]+)") do
    -- insert firts char only
    table.insert(folders, folder)
  end
  -- File to string
  file = tostring(file)
  -- Count the number of slashes in the relative file path
  local slash_count = 0
  for _ in string.gmatch(file, "/") do
    slash_count = slash_count + 1
  end
  if slash_count == 0 then
    short_name = utils.get_file_name(file)
  else
    -- Return the file name preceded by the number of slashes
    short_name = slash_count .. "|" .. utils.get_file_name(file)
  end
  -- Check if the file name is already in the list of short file names
  -- If so, return the short file name with one number in front of it
  local i = 1
  while key_in_table(short_name, current_short_fns) do
    local folder = folders[i]
    if folder == nil then
      folder = i
    end
    short_name =  short_name.." ("..folder..")"
    i = i + 1
  end
  return short_name
end



function utils.get_short_term_name(term_name)
  return term_name:gsub("://.*//", ":")
end

function utils.absolute_path(item)
  return Path:new(item):absolute()
end

function utils.is_white_space(str)
  return str:gsub("%s", "") == ""
end

function utils.buffer_is_valid(buf_id, buf_name)
    return 1 == vim.fn.buflisted(buf_id)
      and buf_name ~= ""
end


-- tbl_deep_extend does not work the way you would think
local function merge_table_impl(t1, t2)
  assert(type(t1) == "table")
  if type(t2) == "table" then
    for k, v in pairs(t2) do
      if type(v) == "table" then
        if type(t1[k]) == "table" then
          merge_table_impl(t1[k], v)
        else
          t1[k] = v
        end
      else
        t1[k] = v
      end
    end
  end
end


function utils.merge_tables(...)
  local out = {}
  for i = 1, select("#", ...) do
    merge_table_impl(out, select(i, ...))
  end
  return out
end

function utils.extend_table(t1, t2)
  assert(t1, "table t1 cannot be nil")
  if type(t2) ~= "table" then
    return
  end

  for k, v in pairs(t2) do
    if type(v) == "table" then
      if type(t1[k]) == "table" then
        utils.extend_table(t1[k], v)
      else 
        t1[k] = v
      end
    else 
      t1[k] = v
    end
  end
end

function utils.deep_copy(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[utils.deep_copy(k, s)] = utils.deep_copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

function utils.echoerr(msg)
  vim.cmd(string.format("echoerr '%s'", msg))
end

function utils.echo(msg)
  vim.cmd(string.format("echo '%s'", msg))
end

function utils.lock_buf(bufnr)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end
function utils.unlock_buf(bufnr)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
end

-- return winid of a buffer
-- if it is not in any window, return nil
function utils.get_buf_winid(bufnr)
  local all_wins = vim.api.nvim_list_wins()
  for _, winid in pairs(all_wins) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
  return nil
end

function utils.edit_buffer(menu) 
  local bufnr = menu:get_cur_bufnr()
  local buf_winid = utils.get_buf_winid(bufnr)

  menu.ui_mod:close()

  if buf_winid then
    vim.api.nvim_set_current_win(buf_winid)
  else 
    vim.cmd(string.format("buffer %d", bufnr))
  end
end

function utils.tabnew_buffer(menu) 
  local bufnr = menu:get_cur_bufnr()
  local buf_winid = utils.get_buf_winid(bufnr)

  menu.ui_mod:close()

  if buf_winid then
    vim.api.nvim_set_current_win(buf_winid)
  else
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    vim.cmd(string.format("tabnew %s", buf_name))
  end
end

function utils.delete_buffer(menu)
  local bufnr = menu:get_cur_bufnr()

  if vim.api.nvim_buf_is_valid(bufnr) then
    -- don't delete modified buffers
    if vim.bo[bufnr].modified then
      utils.echo(string.format("buffer %s is modified", vim.api.nvim_buf_get_name(bufnr)))
      return
    end
    
    vim.api.nvim_buf_delete(bufnr, { force = false })
    assert(not vim.api.nvim_buf_is_valid(bufnr), 
      string.format("try to delete buffer %d failed", bufnr))
  end

  menu:update()
end

function utils.force_delete_buffer(menu)
  local bufnr = menu:get_cur_bufnr()
  vim.api.nvim_buf_delete(bufnr, { force = true })
  menu:update()
end

function utils.toggle_buf_name(menu)
  local index = vim.fn.line(".")
  local bufnr = menu.buf_list[index].bufnr
  local buf_name = vim.api.nvim_buf_get_name(bufnr)

  assert(menu.durable_buf_table[bufnr])
  local name_toggled = menu.durable_buf_table[bufnr].name_toggled

  if name_toggled then
    menu.durable_buf_table[bufnr].name = 
      utils.normalize_path(buf_name)
  else 
    menu.durable_buf_table[bufnr].name = buf_name
  end

  menu.durable_buf_table[bufnr].name_toggled = not name_toggled

  local buf_line = menu:format_buf_line(index)

  vim.api.nvim_buf_set_option(menu.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(menu.bufnr, index-1, index, false, {buf_line})
  vim.api.nvim_buf_set_option(menu.bufnr, "modified", false)
  vim.api.nvim_buf_set_option(menu.bufnr, "modifiable", false)
end

return utils
