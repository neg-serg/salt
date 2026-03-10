-- Swayimg Lua configuration
-- All keybindings are explicit (bind_reset clears C++ defaults).

local home = os.getenv("HOME")
local actions = home .. "/.local/bin/swayimg-actions.sh"
local trash = home .. "/trash/1st-level/pic"

-- Helper: run swayimg-actions.sh with current file path (non-blocking)
local function run(mode, args)
    local image = mode.current_image()
    local file_path = image["path"]:gsub("'", "'\\''")
    os.execute(actions .. " " .. args .. " '" .. file_path .. "' &")
end

-- Helper: run swayimg-actions.sh with extra trailing arg
local function run_to(mode, args, dest)
    local image = mode.current_image()
    local file_path = image["path"]:gsub("'", "'\\''")
    os.execute(actions .. " " .. args .. " '" .. file_path .. "' " .. dest .. " &")
end

-- Shared toggle helpers
local info_visible = true
local aa_enabled = true
local slideshow_paused = false

local function toggle_info()
    info_visible = not info_visible
    if info_visible then swayimg.text.show() else swayimg.text.hide() end
end

local function toggle_aa()
    aa_enabled = not aa_enabled
    swayimg.enable_antialiasing(aa_enabled)
end

local function fullscreen()
    os.execute("hyprctl dispatch fullscreen 1 &")
end

-- Pan helper: move image by fraction of window size
local function viewer_pan(mode, dx_frac, dy_frac)
    local w, h = unpack(swayimg.get_window_size())
    local x, y = unpack(mode.get_position())
    mode.set_abs_position(
        math.floor(x + w * dx_frac),
        math.floor(y + h * dy_frac))
end

--------------------------------------------------------------------------------
-- General settings
--------------------------------------------------------------------------------
swayimg.enable_decoration(false)
swayimg.enable_overlay(true)

--------------------------------------------------------------------------------
-- Image list
--------------------------------------------------------------------------------
swayimg.imagelist.set_order("none")
swayimg.imagelist.enable_recursive(false)

--------------------------------------------------------------------------------
-- Font / text
--------------------------------------------------------------------------------
swayimg.text.set_font("Iosevka")
swayimg.text.set_size(14)
swayimg.text.set_foreground(0xffb8c5d9)
swayimg.text.set_shadow(0xee000000)
swayimg.text.set_background(0xee000000)
swayimg.text.set_timer(1)
swayimg.text.set_status_timer(2)

--------------------------------------------------------------------------------
-- Viewer settings
--------------------------------------------------------------------------------
swayimg.viewer.set_window_background(0x00000000)
swayimg.viewer.set_image_background(0xff000000)
swayimg.viewer.set_default_scale("optimal")
swayimg.viewer.set_default_position("center")
swayimg.viewer.enable_loop(false)
swayimg.viewer.set_history_limit(4)
swayimg.viewer.set_preload_limit(16)

swayimg.viewer.set_text_tl({})
swayimg.viewer.set_text_tr({})
swayimg.viewer.set_text_bl({ "{path}" })
swayimg.viewer.set_text_br({ "{list.index}/{list.total}", "{status}" })

--------------------------------------------------------------------------------
-- Gallery settings
--------------------------------------------------------------------------------
swayimg.gallery.set_thumb_size(200)
swayimg.gallery.set_aspect("fill")
swayimg.gallery.set_cache_size(100000)
swayimg.gallery.enable_preload(true)
swayimg.gallery.enable_pstore(true)
swayimg.gallery.set_padding_size(4)
swayimg.gallery.set_border_size(3)
swayimg.gallery.set_border_color(0xff005f87)
swayimg.gallery.set_selected_scale(1.15)
swayimg.gallery.set_selected_color(0xff002d59)
swayimg.gallery.set_background_color(0xff080808)
swayimg.gallery.set_window_color(0xff000000)

swayimg.gallery.set_text_tl({})
swayimg.gallery.set_text_tr({})
swayimg.gallery.set_text_bl({ "{path}" })
swayimg.gallery.set_text_br({ "{list.index}/{list.total}", "{status}" })

--------------------------------------------------------------------------------
-- Slideshow settings
--------------------------------------------------------------------------------
swayimg.slideshow.set_timeout(3)

--------------------------------------------------------------------------------
-- Signal handlers (USR1 = prev, USR2 = next)
--------------------------------------------------------------------------------
swayimg.viewer.on_signal("USR1", function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_signal("USR2", function() swayimg.viewer.open("next") end)
swayimg.gallery.on_signal("USR1", function() swayimg.gallery.select("left") end)
swayimg.gallery.on_signal("USR2", function() swayimg.gallery.select("right") end)
swayimg.slideshow.on_signal("USR1", function() swayimg.slideshow.open("prev") end)
swayimg.slideshow.on_signal("USR2", function() swayimg.slideshow.open("next") end)

--------------------------------------------------------------------------------
-- Viewer keybindings (all explicit)
--------------------------------------------------------------------------------
swayimg.viewer.bind_reset()
swayimg.viewer.bind_drag("MouseLeft")

-- Exit / mode switching
swayimg.viewer.on_key("Escape", function() swayimg.exit() end)
swayimg.viewer.on_key("q", function() swayimg.exit() end)
swayimg.viewer.on_key("Return", function() swayimg.set_mode("gallery") end)
swayimg.viewer.on_key("s", function() swayimg.set_mode("slideshow") end)

-- File navigation
swayimg.viewer.on_key("n", function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("p", function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("BackSpace", function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("g", function() swayimg.viewer.open("first") end)
swayimg.viewer.on_key("Shift+g", function() swayimg.viewer.open("last") end)
swayimg.viewer.on_key("Next", function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("Prior", function() swayimg.viewer.open("prev") end)

-- Frame navigation (animated images)
swayimg.viewer.on_key("Shift+Next", function()
    swayimg.viewer.animation_stop()
    swayimg.viewer.next_frame()
end)
swayimg.viewer.on_key("Shift+Prior", function()
    swayimg.viewer.animation_stop()
    swayimg.viewer.prev_frame()
end)

-- Panning: hjkl (vim) + arrows (1/10 of window)
swayimg.viewer.on_key("h", function() viewer_pan(swayimg.viewer, -0.1, 0) end)
swayimg.viewer.on_key("l", function() viewer_pan(swayimg.viewer, 0.1, 0) end)
swayimg.viewer.on_key("k", function() viewer_pan(swayimg.viewer, 0, -0.1) end)
swayimg.viewer.on_key("j", function() viewer_pan(swayimg.viewer, 0, 0.1) end)
swayimg.viewer.on_key("Left", function() viewer_pan(swayimg.viewer, -0.1, 0) end)
swayimg.viewer.on_key("Right", function() viewer_pan(swayimg.viewer, 0.1, 0) end)
swayimg.viewer.on_key("Up", function() viewer_pan(swayimg.viewer, 0, -0.1) end)
swayimg.viewer.on_key("Down", function() viewer_pan(swayimg.viewer, 0, 0.1) end)

-- Zoom
swayimg.viewer.on_key("0", function() swayimg.viewer.set_fix_scale("real") end)
swayimg.viewer.on_key("equal", function()
    local s = swayimg.viewer.get_scale()
    swayimg.viewer.set_abs_scale(s + s / 10)
end)
swayimg.viewer.on_key("minus", function()
    local s = swayimg.viewer.get_scale()
    swayimg.viewer.set_abs_scale(s - s / 10)
end)

-- Toggles
swayimg.viewer.on_key("a", toggle_aa)
swayimg.viewer.on_key("f", fullscreen)
swayimg.viewer.on_key("i", toggle_info)
swayimg.viewer.on_key("Insert", function() swayimg.imagelist.mark() end)

-- Image transforms (native Lua API)
swayimg.viewer.on_key("bracketleft", function() swayimg.viewer.rotate(270) end)
swayimg.viewer.on_key("bracketright", function() swayimg.viewer.rotate(90) end)
swayimg.viewer.on_key("m", function() swayimg.viewer.flip_vertical() end)

-- File actions via swayimg-actions.sh
swayimg.viewer.on_key("c", function() run(swayimg.viewer, "copyname") end)
swayimg.viewer.on_key("d", function() run_to(swayimg.viewer, "mv", trash) end)
swayimg.viewer.on_key("r", function() run(swayimg.viewer, "repeat") end)
swayimg.viewer.on_key("v", function() run(swayimg.viewer, "mv") end)

-- Ctrl actions
swayimg.viewer.on_key("Ctrl+1", function() run(swayimg.viewer, "wall-mono") end)
swayimg.viewer.on_key("Ctrl+2", function() run(swayimg.viewer, "wall-fill") end)
swayimg.viewer.on_key("Ctrl+3", function() run(swayimg.viewer, "wall-full") end)
swayimg.viewer.on_key("Ctrl+4", function() run(swayimg.viewer, "wall-tile") end)
swayimg.viewer.on_key("Ctrl+5", function() run(swayimg.viewer, "wall-center") end)
swayimg.viewer.on_key("Ctrl+c", function() run(swayimg.viewer, "cp") end)
swayimg.viewer.on_key("Ctrl+d", function() run_to(swayimg.viewer, "mv", trash) end)
swayimg.viewer.on_key("Ctrl+w", function() run(swayimg.viewer, "wall-cover") end)
swayimg.viewer.on_key("Ctrl+comma", function() run(swayimg.viewer, "rotate-left") end)
swayimg.viewer.on_key("Ctrl+period", function() run(swayimg.viewer, "rotate-right") end)
swayimg.viewer.on_key("Ctrl+slash", function() run(swayimg.viewer, "rotate-180") end)
swayimg.viewer.on_key("Ctrl+less", function() run(swayimg.viewer, "rotate-ccw") end)

-- Shift actions (range operations)
swayimg.viewer.on_key("Shift+c", function() run(swayimg.viewer, "range-cp") end)
swayimg.viewer.on_key("Shift+d", function() run(swayimg.viewer, "range-trash") end)
swayimg.viewer.on_key("Shift+m", function() run(swayimg.viewer, "range-mark") end)
swayimg.viewer.on_key("Shift+r", function() run(swayimg.viewer, "range-clear") end)
swayimg.viewer.on_key("Shift+v", function() run(swayimg.viewer, "range-mv") end)

-- Mouse: scroll = pan, Ctrl+scroll = zoom
swayimg.viewer.on_mouse("ScrollUp", function()
    local x, y = unpack(swayimg.viewer.get_position())
    swayimg.viewer.set_abs_position(x, y + 20)
end)
swayimg.viewer.on_mouse("ScrollDown", function()
    local x, y = unpack(swayimg.viewer.get_position())
    swayimg.viewer.set_abs_position(x, y - 20)
end)
swayimg.viewer.on_mouse("ScrollLeft", function()
    local x, y = unpack(swayimg.viewer.get_position())
    swayimg.viewer.set_abs_position(x + 20, y)
end)
swayimg.viewer.on_mouse("ScrollRight", function()
    local x, y = unpack(swayimg.viewer.get_position())
    swayimg.viewer.set_abs_position(x - 20, y)
end)
swayimg.viewer.on_mouse("Ctrl+ScrollUp", function()
    local mx, my = unpack(swayimg.get_mouse_pos())
    local s = swayimg.viewer.get_scale()
    swayimg.viewer.set_abs_scale(s + s / 10, mx, my)
end)
swayimg.viewer.on_mouse("Ctrl+ScrollDown", function()
    local mx, my = unpack(swayimg.get_mouse_pos())
    local s = swayimg.viewer.get_scale()
    swayimg.viewer.set_abs_scale(s - s / 10, mx, my)
end)

--------------------------------------------------------------------------------
-- Gallery keybindings (all explicit)
--------------------------------------------------------------------------------
swayimg.gallery.bind_reset()

-- Exit / mode switching
swayimg.gallery.on_key("Escape", function() swayimg.exit() end)
swayimg.gallery.on_key("q", function() swayimg.exit() end)
swayimg.gallery.on_key("Return", function() swayimg.set_mode("viewer") end)
swayimg.gallery.on_key("s", function() swayimg.set_mode("slideshow") end)

-- Navigation: hjkl (vim) + arrows + Home/End + PgUp/PgDn
swayimg.gallery.on_key("h", function() swayimg.gallery.select("left") end)
swayimg.gallery.on_key("l", function() swayimg.gallery.select("right") end)
swayimg.gallery.on_key("k", function() swayimg.gallery.select("up") end)
swayimg.gallery.on_key("j", function() swayimg.gallery.select("down") end)
swayimg.gallery.on_key("Left", function() swayimg.gallery.select("left") end)
swayimg.gallery.on_key("Right", function() swayimg.gallery.select("right") end)
swayimg.gallery.on_key("Up", function() swayimg.gallery.select("up") end)
swayimg.gallery.on_key("Down", function() swayimg.gallery.select("down") end)
swayimg.gallery.on_key("g", function() swayimg.gallery.select("first") end)
swayimg.gallery.on_key("Shift+g", function() swayimg.gallery.select("last") end)
swayimg.gallery.on_key("Home", function() swayimg.gallery.select("first") end)
swayimg.gallery.on_key("End", function() swayimg.gallery.select("last") end)
swayimg.gallery.on_key("Prior", function() swayimg.gallery.select("pgup") end)
swayimg.gallery.on_key("Next", function() swayimg.gallery.select("pgdown") end)

-- Thumbnail size
swayimg.gallery.on_key("0", function() swayimg.gallery.set_thumb_size(200) end)
swayimg.gallery.on_key("equal", function()
    swayimg.gallery.set_thumb_size(swayimg.gallery.get_thumb_size() + 16)
end)
swayimg.gallery.on_key("minus", function()
    swayimg.gallery.set_thumb_size(math.max(50, swayimg.gallery.get_thumb_size() - 16))
end)

-- Toggles
swayimg.gallery.on_key("a", toggle_aa)
swayimg.gallery.on_key("f", fullscreen)
swayimg.gallery.on_key("i", toggle_info)
swayimg.gallery.on_key("Insert", function() swayimg.imagelist.mark() end)

-- File actions
swayimg.gallery.on_key("c", function() run(swayimg.gallery, "copyname") end)
swayimg.gallery.on_key("d", function() run_to(swayimg.gallery, "mv", trash) end)
swayimg.gallery.on_key("r", function() run(swayimg.gallery, "repeat") end)
swayimg.gallery.on_key("v", function() run(swayimg.gallery, "mv") end)

-- Ctrl actions
swayimg.gallery.on_key("Ctrl+1", function() run(swayimg.gallery, "wall-mono") end)
swayimg.gallery.on_key("Ctrl+2", function() run(swayimg.gallery, "wall-fill") end)
swayimg.gallery.on_key("Ctrl+3", function() run(swayimg.gallery, "wall-full") end)
swayimg.gallery.on_key("Ctrl+4", function() run(swayimg.gallery, "wall-tile") end)
swayimg.gallery.on_key("Ctrl+5", function() run(swayimg.gallery, "wall-center") end)
swayimg.gallery.on_key("Ctrl+c", function() run(swayimg.gallery, "cp") end)
swayimg.gallery.on_key("Ctrl+d", function() run_to(swayimg.gallery, "mv", trash) end)
swayimg.gallery.on_key("Ctrl+w", function() run(swayimg.gallery, "wall-cover") end)
swayimg.gallery.on_key("Ctrl+comma", function() run(swayimg.gallery, "rotate-left") end)
swayimg.gallery.on_key("Ctrl+period", function() run(swayimg.gallery, "rotate-right") end)
swayimg.gallery.on_key("Ctrl+slash", function() run(swayimg.gallery, "rotate-180") end)
swayimg.gallery.on_key("Ctrl+less", function() run(swayimg.gallery, "rotate-ccw") end)

-- Shift actions (range operations)
swayimg.gallery.on_key("Shift+c", function() run(swayimg.gallery, "range-cp") end)
swayimg.gallery.on_key("Shift+d", function() run(swayimg.gallery, "range-trash") end)
swayimg.gallery.on_key("Shift+m", function() run(swayimg.gallery, "range-mark") end)
swayimg.gallery.on_key("Shift+r", function() run(swayimg.gallery, "range-clear") end)
swayimg.gallery.on_key("Shift+v", function() run(swayimg.gallery, "range-mv") end)

-- Mouse: click = open, scroll = navigate, Ctrl+scroll = thumb resize
swayimg.gallery.on_mouse("MouseLeft", function() swayimg.set_mode("viewer") end)
swayimg.gallery.on_mouse("ScrollUp", function() swayimg.gallery.select("up") end)
swayimg.gallery.on_mouse("ScrollDown", function() swayimg.gallery.select("down") end)
swayimg.gallery.on_mouse("ScrollLeft", function() swayimg.gallery.select("left") end)
swayimg.gallery.on_mouse("ScrollRight", function() swayimg.gallery.select("right") end)
swayimg.gallery.on_mouse("Ctrl+ScrollUp", function()
    swayimg.gallery.set_thumb_size(swayimg.gallery.get_thumb_size() + 16)
end)
swayimg.gallery.on_mouse("Ctrl+ScrollDown", function()
    swayimg.gallery.set_thumb_size(math.max(50, swayimg.gallery.get_thumb_size() - 16))
end)

--------------------------------------------------------------------------------
-- Slideshow keybindings (all explicit)
--------------------------------------------------------------------------------
swayimg.slideshow.bind_reset()
swayimg.slideshow.bind_drag("MouseLeft")

-- Exit / mode switching
swayimg.slideshow.on_key("Escape", function() swayimg.exit() end)
swayimg.slideshow.on_key("q", function() swayimg.exit() end)
swayimg.slideshow.on_key("s", function() swayimg.set_mode("viewer") end)

-- Pause / play
swayimg.slideshow.on_key("space", function()
    slideshow_paused = not slideshow_paused
    if slideshow_paused then
        swayimg.slideshow.set_timeout(0)
        swayimg.set_status("Paused")
    else
        swayimg.slideshow.set_timeout(3)
        swayimg.set_status("Playing")
    end
end)

-- Navigation
swayimg.slideshow.on_key("n", function() swayimg.slideshow.open("next") end)
swayimg.slideshow.on_key("p", function() swayimg.slideshow.open("prev") end)
swayimg.slideshow.on_key("BackSpace", function() swayimg.slideshow.open("prev") end)
swayimg.slideshow.on_key("Next", function() swayimg.slideshow.open("next") end)
swayimg.slideshow.on_key("Prior", function() swayimg.slideshow.open("prev") end)

-- Toggles
swayimg.slideshow.on_key("f", fullscreen)
swayimg.slideshow.on_key("i", toggle_info)

-- File actions
swayimg.slideshow.on_key("Ctrl+d", function() run_to(swayimg.slideshow, "mv", trash) end)
swayimg.slideshow.on_key("Shift+c", function() run(swayimg.slideshow, "range-cp") end)
swayimg.slideshow.on_key("Shift+d", function() run(swayimg.slideshow, "range-trash") end)
swayimg.slideshow.on_key("Shift+m", function() run(swayimg.slideshow, "range-mark") end)
swayimg.slideshow.on_key("Shift+r", function() run(swayimg.slideshow, "range-clear") end)
swayimg.slideshow.on_key("Shift+v", function() run(swayimg.slideshow, "range-mv") end)
