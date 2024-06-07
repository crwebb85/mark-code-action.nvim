local config = require('mark-code-action.config')

local M = {}
local ms = vim.lsp.protocol.Methods

---@class MarkCodeAction.hover.Opts
---
---Predicate used to filter clients. Receives a client as argument and
---must return a boolean. Clients matching the predicate are included.
---@field filter? fun(client: vim.lsp.Client): boolean?
---
---Restrict clients used for rename to ones where client.name matches
---this field.
---@field client_name? string
---
--- Lsp timeout
---@field lsp_timeout_ms? uinteger

function M.hover(opts)
    opts = opts or {}
    local timeout_ms = opts.timeout_ms or config.get_config().lsp_timeout_ms
    local bufnr = vim.api.nvim_get_current_buf()

    local params = vim.lsp.util.make_position_params()

    local ctx = {
        method = ms.textDocument_hover,
        params = params,
        bufnr = bufnr,
    }

    local clients = vim.lsp.get_clients({
        bufnr = bufnr,
        name = opts.client_name,
        method = ms.textDocument_hover,
    })

    if opts.filter then
        clients = vim.tbl_filter(opts.filter, clients)
    end

    if #clients == 0 then
        -- If no Lsp clients are attached we want to
        -- throw an error to cancel any currently running macro
        error('No valid lsp client attached')
    end

    ---@type string[]
    local error_messages = {}
    for _, client in ipairs(clients) do
        local response, err = client.request_sync(ms.textDocument_hover, params, timeout_ms, bufnr)
        if err == 'timeout' then
            table.insert(error_messages, client.name .. ' timed out')
        elseif err ~= nil then
            table.insert(error_messages, client.name .. ' had client err ' .. err)
        elseif response == nil then
            table.insert(error_messages, client.name .. ' client returned an empty response')
        elseif response.err ~= nil then
            table.insert(
                error_messages,
                client.name .. ' server sent an the error ' .. response.err.code .. ':' .. response.err.message
            )
        elseif response.result == nil then
            table.insert(error_messages, client.name .. ' server sent an empty result')
        elseif response.result ~= nil then
            ctx.client_id = client.id
            -- For now I am going to use the hover handler. In the future, I may
            -- need to consider switching to my own hover handler override mechanism
            local hover_handler = client.handlers[ms.textDocument_hover] or vim.lsp.handlers[ms.textDocument_hover]
            hover_handler(nil, response.result, ctx, {})
            return
        end
    end
    if #error_messages == 0 then
        error('Something unexpected went wrong')
    else
        table.insert(error_messages, 1, 'During ' .. ms.textDocument_hover .. ' request:')
        local error_message = vim.fn.join(error_messages, '\n')
        error(error_message)
    end
end

return M
