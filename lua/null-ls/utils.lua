local methods = require("null-ls.methods")
local api = vim.api

local M = {}

local get_content_from_params = function(params)
    -- diagnostic notifications will send full buffer content on open and change
    -- so we can avoid unnecessary api calls
    if params.method == methods.lsp.DID_OPEN and params.textDocument and
        params.textDocument.text then
        return vim.split(params.textDocument.text, "\n")
    end
    if params.method == methods.lsp.DID_CHANGE and params.contentChanges and
        params.contentChanges[1] and params.contentChanges[1].text then
        return vim.split(params.contentChanges[1].text, "\n")
    end

    -- for other methods, fall back to manually getting content
    return M.buf.content(params.bufnr)
end

M.echo = function(hlgroup, message)
    api.nvim_echo({{"null-ls: " .. message, hlgroup}}, true, {})
end

M.filetype_matches = function(handler, ft)
    return not handler.filetypes or vim.tbl_contains(handler.filetypes, ft)
end

M.make_params = function(original_params, method)
    local bufnr = original_params.bufnr
    local lsp_method = original_params.method
    local uri = original_params.textDocument and
                    original_params.textDocument.uri or
                    vim.uri_from_bufnr(bufnr)

    local pos = api.nvim_win_get_cursor(0)
    local content = get_content_from_params(original_params)

    return {
        content = content,
        lsp_method = lsp_method,
        method = method,
        row = pos[1],
        col = pos[2],
        bufnr = bufnr,
        uri = uri,
        bufname = api.nvim_buf_get_name(bufnr),
        ft = api.nvim_buf_get_option(bufnr, "filetype")
    }
end

M.buf = {
    content = function(bufnr, to_string)
        if not bufnr then bufnr = api.nvim_get_current_buf() end
        local eol = api.nvim_buf_get_option(bufnr, "eol")

        local split = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if to_string then
            local text = table.concat(split, "\n")
            return eol and text .. "\n" or text
        end

        if eol then table.insert(split, "\n") end
        return split
    end
}

M.string = {
    replace = function(str, original, replacement)
        local found, found_end = string.find(str, original, nil, true)
        if not found then return end

        if str == original then return replacement end

        local first_half = string.sub(str, 0, found - 1)
        local second_half = string.sub(str, found_end + 1)

        return first_half .. replacement .. second_half
    end,

    to_number_safe = function(str, default, offset)
        if not str then return default end

        local number = tonumber(str)
        return offset and number + offset or number
    end
}

return M