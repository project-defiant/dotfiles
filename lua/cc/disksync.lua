local M = {}

local GROUP = "cc_disksync"

--- Decide what to do when a buffer's file changed on disk.
---@param bufnr integer
---@param reason string  v:fcs_reason ("changed", "conflict", "deleted", "mode", "time")
---@return "reload"|""
function M.decide(bufnr, reason)
  if not vim.bo[bufnr].modified and reason ~= "deleted" then
    return "reload"
  end
  vim.b[bufnr].cc_disk_conflict = reason
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
  local what = reason == "deleted" and "was deleted on disk" or "changed on disk (you have unsaved edits)"
  vim.notify(("%s %s; buffer kept. Use :CcDiffDisk to compare."):format(name, what), vim.log.levels.WARN)
  return ""
end

function M.diff_disk()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.fn.filereadable(path) == 0 then
    vim.notify("CcDiffDisk: file no longer exists on disk", vim.log.levels.WARN)
    return
  end
  local ft = vim.bo[buf].filetype
  local lines = vim.fn.readfile(path)
  vim.cmd("diffthis")
  vim.cmd("vertical new")
  local scratch = vim.api.nvim_get_current_buf()
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false
  vim.bo[scratch].filetype = ft
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
  vim.bo[scratch].modifiable = false
  pcall(vim.api.nvim_buf_set_name, scratch, "disk://" .. path)
  vim.cmd("diffthis")
end

function M.setup()
  vim.o.autoread = true
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    group = group,
    callback = function()
      if vim.o.buftype ~= "" or vim.fn.getcmdwintype() ~= "" then
        return
      end
      vim.cmd("silent! checktime")
    end,
  })

  -- Presence of this handler suppresses Neovim's own reload/prompt.
  vim.api.nvim_create_autocmd("FileChangedShell", {
    group = group,
    callback = function(ev)
      vim.v.fcs_choice = M.decide(ev.buf, vim.v.fcs_reason)
    end,
  })

  vim.api.nvim_create_user_command("CcDiffDisk", M.diff_disk, {
    force = true,
    desc = "Diff current buffer against its on-disk file",
  })
end

return M
