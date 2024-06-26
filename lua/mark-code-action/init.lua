local action = require('mark-code-action.action')
local config = require('mark-code-action.config')

---@class MarkCodeAction.CodeActionIdentifier
---@field client_id? number id of the lsp client (at the time of making the mark)
---@field client_name string name of the lsp client
---@field kind string lsp action kind
---@field title string lsp action title
---@field full_action? lsp.Command|lsp.CodeAction of the lsp code action (at the time of making the mark)
---@field picker? string picker name

---@alias MarkCodeAction.CodeActionMark string

---@alias MarkCodeAction.LinePosition integer[]  in the form {row, col} using (1, 0) indexing

---@class MarkCodeAction.TextRange
---@field start MarkCodeAction.LinePosition
---@field end MarkCodeAction.LinePosition

---@class MarkCodeAction.RunMarkOptions
---@field mark_name string name of mark
---@field bufnr integer? buffer number (default = 0)
---@field is_range_selection boolean? whether to use range params to select code action (default = false)
---@field lsp_timeout_ms? integer the timeout in milliseconds used when making syncronous lsp requests (default=2000)

---@class MarkCodeAction.MarkSelectionOptions
---@field mark_name string name of mark
---@field bufnr integer? buffer number (default=0)
---@field is_range_selection boolean? whether to use range params to select code action (default = false)

---@alias MarkCodeAction.CodeActionPicker fun(action_identifier: MarkCodeAction.CodeActionIdentifier, code_action: lsp.CodeAction, client_id: integer): boolean

---@class MarkCodeAction.PickedCodeAction
---@field client_id integer
---@field lsp_action lsp.CodeAction

---@class MarkCodeAction.MarkCodeActionAPI
local M = {}

---@class MarkCodeAction.MarkCodeActionConfig
---@field marks? {[MarkCodeAction.CodeActionMark]: MarkCodeAction.CodeActionIdentifier}
---@field lsp_timeout_ms? integer the timeout in milliseconds used when making syncronous lsp requests (default=2000)

---@param opts MarkCodeAction.MarkCodeActionConfig?
M.setup = function(opts)
    config.set_config(opts)
    action.merge_code_action_marks(config.get_config())

    require('mark-code-action.command') -- load commands
end

M.get_code_action_identifier_by_mark = action.get_code_action_identifier_by_mark
M.get_code_action_marks = action.get_code_action_marks
M.get_config = config.get_config

return M
