local action = require('mark-code-action.action')

---@class MarkCodeActionConfig
local config = {}

---@class MarkCodeActionAPI
local M = {}

---@type MarkCodeActionConfig
M.config = config

---@param opts MarkCodeActionConfig?
M.setup = function(opts)
    M.config = vim.tbl_deep_extend('force', M.config, opts or {})

    vim.api.nvim_create_user_command('MarkCodeActionMark', action.command_mark, {
        desc = 'Marks a Code Action item',
        nargs = '?', --0 or 1 param
        range = true,
    })

    vim.api.nvim_create_user_command('MarkCodeActionRun', action.command_run_mark, {
        desc = 'Runs a Code Action Mark',
        nargs = 1, --0 or 1 param
        complete = action.get_code_action_marks,
        range = true,
    })
end

return M
