local M = {}

---@class CodeActionIdentifier
---@field client_id? number id of the lsp client (at the time of making the mark)
---@field client_name string name of the lsp client
---@field kind string lsp action kind
---@field title string lsp action title
---@field full_action? lsp.Command|lsp.CodeAction of the lsp code action (at the time of making the mark)

---@class CommandOpts
---@field name string
---@field args string
---@field fargs string[]
---@field bang boolean
---@field line1 number
---@field line2 number
---@field range number
---@field count number
---@field reg string
---@field mods string
---@field smods string[]

---@alias CodeActionMark string

---@alias LinePosition integer[]  in the form {row, col} using (1, 0) indexing

---@class TextRange
---@field start LinePosition
---@field end LinePosition

---@type {[CodeActionMark]: CodeActionIdentifier}
local code_action_marks = {} -- Stores the code action marks

---@private
---@param bufnr integer
---@return TextRange {start={row, col}, end={row, col}} using (1, 0) indexing
local function range_from_selection(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local start_row = start_pos[1]
    local start_col = start_pos[2]

    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    local end_row = end_pos[1]
    local end_col = end_pos[2]

    return {
        ['start'] = { start_row, start_col - 1 },
        ['end'] = { end_row, end_col - 1 },
    }
end

---@param bufnr integer buffer number
---@param is_range boolean true if code action params over a range
---@return lsp.CodeActionParams
local function build_code_action_params(bufnr, is_range)
    local params
    if is_range then
        local range = range_from_selection(bufnr)

        --TODO check for off by one errors
        params = vim.lsp.util.make_given_range_params(range.start, range['end'])
    else
        params = vim.lsp.util.make_range_params()
    end
    params.context = {
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
        diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr),
    }
    return params
end

--- @param opts CommandOpts
function M.command_mark(opts)
    local mark_name = opts.args

    local bufnr = vim.api.nvim_get_current_buf()

    local is_range = (opts.range == 2)
    local params = build_code_action_params(bufnr, is_range)

    vim.lsp.buf_request_all(bufnr, 'textDocument/codeAction', params, function(results)
        ---@type CodeActionIdentifier[]
        local actions = {}

        ---@type string[]
        local action_selection_list = { 'Select a code action to mark:\n' }

        local index = 1
        for client_id, result in pairs(results) do
            local client = vim.lsp.get_client_by_id(client_id)
            if client ~= nil then
                for _, lsp_action in pairs(result.result or {}) do
                    ---@type CodeActionIdentifier
                    local action_identifier = {
                        client_id = client_id,
                        client_name = client.name,
                        kind = lsp_action.kind,
                        title = lsp_action.title,
                        full_action = lsp_action,
                    }
                    table.insert(actions, action_identifier)

                    local action_selection_text = index .. '. ' .. lsp_action.title
                    table.insert(action_selection_list, action_selection_text)

                    index = index + 1
                end
            end
        end

        if #actions == 0 then
            vim.notify('No code actions available\n', vim.log.levels.ERROR)
            return
        end

        --prompt user to select the code action to mark
        local selection = vim.fn.inputlist(action_selection_list)
        local selection_index = tonumber(selection)
        local selected_action = actions[selection_index]
        if selected_action == nil then
            vim.notify('Not a valid selection\n', vim.log.levels.ERROR)
            return
        end

        --prompt for a mark name if one wasn't already provided
        if mark_name == nil or mark_name:gsub('%s+', '') == '' then
            mark_name = vim.fn.input({ prompt = '\nMark name:\n', default = '0' })
        end

        if mark_name ~= nil then
            code_action_marks[mark_name] = selected_action
        else
            vim.notify('No mark name entered\n', vim.log.levels.ERROR)
        end
    end)
end

--- based on https://github.com/neovim/neovim/blob/8e5c48b08dad54706500e353c58ffb91f2684dd3/runtime/lua/vim/lsp/buf.lua#L677
---@param action lsp.Command|lsp.CodeAction
---@param client vim.lsp.Client
---@param ctx lsp.HandlerContext
local function apply_action(action, client, ctx)
    if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    local a_cmd = action.command
    if a_cmd then
        local command = type(a_cmd) == 'table' and a_cmd or action
        ---@diagnostic disable-next-line: param-type-mismatch
        client:_exec_cmd(command, ctx)
    end
end

--- based on https://github.com/neovim/neovim/blob/8e5c48b08dad54706500e353c58ffb91f2684dd3/runtime/lua/vim/lsp/buf.lua#L689
---@param bufnr integer buffer number
---@param client_id integer lsp client id
---@param params lsp.CodeActionParams code action params
---@param action lsp.Command|lsp.CodeAction
local function apply_code_action(bufnr, client_id, params, action)
    local client = vim.lsp.get_client_by_id(client_id)
    if client == nil then
        return
    end

    ---@type lsp.HandlerContext
    local ctx = {
        method = 'textDocument/codeAction',
        client_id = client_id,
        bufnr = bufnr,
        params = params,
    }
    local reg = client.dynamic_capabilities:get('textDocument/codeAction', { bufnr = bufnr })

    local supports_resolve = vim.tbl_get(reg or {}, 'registerOptions', 'resolveProvider')
        or client.supports_method('codeAction/resolve')

    if not action.edit and client and supports_resolve then
        client.request('codeAction/resolve', action, function(err, resolved_action)
            if err then
                if action.command then
                    apply_action(action, client, ctx)
                else
                    vim.notify(err.code .. ': ' .. err.message, vim.log.levels.ERROR)
                end
            else
                apply_action(resolved_action, client, ctx)
            end
        end, bufnr)
    else
        apply_action(action, client, ctx)
    end
end

---@param opts CommandOpts
function M.command_run_mark(opts)
    local mark_name = opts.args

    local bufnr = vim.api.nvim_get_current_buf()

    local is_range = (opts.range == 2)
    local params = build_code_action_params(bufnr, is_range)

    local action_identifier = code_action_marks[mark_name]
    if action_identifier == nil then
        vim.notify('Invalid action mark.', vim.log.levels.INFO)
        return
    end

    local clients = vim.lsp.get_clients({
        bufnr = bufnr,
        method = 'textDocument/codeAction',
    })
    local remaining = #clients
    if remaining == 0 then
        vim.notify('No active LSP clients on buffer.', vim.log.levels.INFO)
        return
    end

    vim.lsp.buf_request_all(bufnr, 'textDocument/codeAction', params, function(results)
        for client_id, result in pairs(results) do
            local client = vim.lsp.get_client_by_id(client_id)
            if client ~= nil and client.name == action_identifier.client_name then
                for _, lsp_action in pairs(result.result or {}) do
                    --TODO convert the condition below into a function that can be overridden in the plugin configuration
                    if lsp_action.kind == action_identifier.kind and lsp_action.title == action_identifier.title then
                        apply_code_action(bufnr, client_id, params, lsp_action)
                        return
                    end
                end
            end
        end
    end)
end

function M.get_code_action_marks()
    local marks = {}
    for mark, _ in pairs(code_action_marks) do
        table.insert(marks, mark)
    end
    return marks
end

return M
