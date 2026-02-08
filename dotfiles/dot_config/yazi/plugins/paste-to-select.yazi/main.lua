local function entry()
local output_file = "/tmp/yazi_clip_content"
os.execute("wl-paste > " .. output_file)
local file = io.open(output_file, "r")
if not file then return end
local path = file:read("*all")
file:close()
if path then
  path = path:gsub("[\n\r]", "")
  if path ~= "" then
    ya.manager_emit("reveal", { path })
    ya.manager_emit("open", { hovered = true })
  end
end
end
return { entry = entry }
