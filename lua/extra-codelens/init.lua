local utils = require('extra-codelens.utils')
local langs = require('extra-codelens.langs')

local M = {}

local namespace = vim.api.nvim_create_namespace("extra-codelens")

function M.on_attach(client, bufnr)
  if client == nil then return end

  -- TODO: If supports textDocument/codelens, fallback to virtualtypes

  if not client.supports_method('textDocument/hover') then
    local err = string.format(
      "nvim-extra-codelens: %s does not support \"textDocument/hover\" command",
      client.name)
    vim.api.nvim_command(string.format("echohl WarningMsg | echo '%s' | echohl None", err))
    return
  end

  M.run_on_buffer(bufnr)
end

function M.run_on_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M._annotate_nodes(bufnr)
  vim.api.nvim_create_autocmd({"BufEnter", "BufWrite", "InsertLeave"}, {
    buffer = bufnr,
    callback = function() M._annotate_nodes(bufnr) end,
  })
end

function M._annotate_nodes(bufnr)
  vim.schedule(function()
    local root = utils.get_root_node(bufnr)

    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    local ft = vim.bo[bufnr].filetype
    local lang = langs.get_lang(ft)

    if lang == nil then
      print("Filetype " .. ft .. " not supported")
      return
    end

    for id, node in lang.declaration_query:iter_captures(root, bufnr, 0, -1) do
      if lang.declaration_query.captures[id] == "declaration_name" then
        M._show_codelens_for_node(bufnr, node, lang)
      end
    end
  end)
end

function M._show_codelens_for_node(bufnr, node, lang)
  local row, col = node:range()

  local params = vim.lsp.util.make_position_params()
  params.position = { line = row, character = col }

  -- TODO: Use buf_request_all
  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
    if err ~= nil then return end

    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, col, {
      virt_text = { { lang.extract_codeinfo(result), "DiagnosticHint" } },
    })
  end)
end

return M
