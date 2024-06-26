local M = {}

---Is string prefix
---@param s string
---@param prefix string
---@return boolean
local function is_prefix(s, prefix)
    return string.sub(s, 1, string.len(prefix)) == prefix
end

---Is string suffix
---@param s string
---@param suffix string
---@return boolean
local function is_suffix(s, suffix)
    return string.sub(s, -#suffix) == suffix
end

---@type table<string,MarkCodeAction.CodeActionPicker>
local pickers = {
    equals = function(action_identifier, code_action, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil
            and client.name == action_identifier.client_name
            and code_action.kind == action_identifier.kind
            and code_action.title == action_identifier.title
    end,

    contains = function(action_identifier, code_action, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil
            and client.name == action_identifier.client_name
            and code_action.kind == action_identifier.kind
            and string.find(code_action.title, action_identifier.title) ~= nil
    end,
    begins_with = function(action_identifier, code_action, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil
            and client.name == action_identifier.client_name
            and code_action.kind == action_identifier.kind
            and is_prefix(code_action.title, action_identifier.title)
    end,
    ends_with = function(action_identifier, code_action, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil
            and client.name == action_identifier.client_name
            and code_action.kind == action_identifier.kind
            and is_suffix(code_action.title, action_identifier.title)
    end,
    --TODO instead of using code_action.title in ends_with, begins_with, and contains
    --pickers, use fields specific to those pickers and have the MarkCodeActionMark
    --command prompt the user to supply them

    -- TODO add vimregex and lua regex pickers
}

---Is the code action picked based on the code action identifier
---@param action_identifier MarkCodeAction.CodeActionIdentifier
---@param code_action lsp.CodeAction
---@param client_id integer
local function is_picked(action_identifier, code_action, client_id)
    local picker = nil
    if action_identifier.picker == nil then
        picker = pickers['equals']
    else
        picker = pickers[action_identifier.picker]
    end

    if picker == nil then
        error('picker ' .. action_identifier.picker .. 'does not exist')
    end

    return picker(action_identifier, code_action, client_id)
end

---Finds the code action mark from the action identifier
---@param action_identifier MarkCodeAction.CodeActionIdentifier
---@param code_actions_lsp_results table<integer, {error?: lsp.ResponseError, result?: lsp.CodeAction}> result Map of client_id:request_result.
---@return MarkCodeAction.PickedCodeAction?
function M.find_code_action(action_identifier, code_actions_lsp_results)
    for client_id, result in pairs(code_actions_lsp_results) do
        for _, lsp_action in pairs(result.result or {}) do
            if is_picked(action_identifier, lsp_action, client_id) then
                return { client_id = client_id, lsp_action = lsp_action }
            end
        end
    end
    return nil
end

return M
