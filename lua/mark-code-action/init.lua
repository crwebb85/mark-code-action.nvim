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
        nargs = 1,
        complete = action.get_code_action_marks,
        range = true,
    })

    vim.api.nvim_create_user_command('MarkCodeActionInspect', function(args)
        local mark = args.args
        vim.print(action.get_code_action_identifier_by_mark(mark))
    end, {
        desc = 'Inspects a Code Action Mark',
        nargs = 1,
        complete = action.get_code_action_marks,
    })
end

M.get_code_action_identifier_by_mark = action.get_code_action_identifier_by_mark
M.get_code_action_marks = action.get_code_action_marks

return M
