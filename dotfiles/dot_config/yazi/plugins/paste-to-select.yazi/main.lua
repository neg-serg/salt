--- @since 25.5.31
--- Read a file path from system clipboard, reveal it, and open (select) it.
--- Useful with --chooser-file (termfilechooser) to quickly pick a known file.
return {
	entry = function()
		local content = ya.clipboard()
		if not content or content == "" then
			return ya.notify { title = "Clipboard", content = "Clipboard is empty", level = "warn", timeout = 2 }
		end

		local path = content:gsub("[\n\r]", "")
		if path == "" then return end

		ya.emit("reveal", { Url(path) })
		ya.emit("open", { hovered = true })
	end,
}
