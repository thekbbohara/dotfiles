-- wezterm.lua
-- Wal-based palette for WezTerm, mirroring ~/.config/hypr/hyprcolors.lua.
-- Reads ~/.cache/wal/colors.json (written by pywal16) and derives the theme.
-- Falls back to Catppuccin Mocha when the palette file is unavailable.

local wezterm = require("wezterm")

local home = os.getenv("HOME") or os.getenv("USERPROFILE")

-- Reload the palette whenever pywal rewrites it, without restarting.
if home and wezterm.add_to_config_reload_watch_list then
    wezterm.add_to_config_reload_watch_list(home .. "/.cache/wal/colors.json")
end

local CATPPUCCIN = {
    background = "1e1e2e",
    foreground = "cdd6f4",
    colors = {
        color0  = "45475a",
        color1  = "f38ba8",
        color2  = "a6e3a1",
        color3  = "f9e2af",
        color4  = "89b4fa",
        color5  = "cba6f7",
        color6  = "94e2d5",
        color7  = "cdd6f4",
        color8  = "585b70",
        color9  = "f38ba8",
        color10 = "a6e3a1",
        color11 = "f9e2af",
        color12 = "89b4fa",
        color13 = "cba6f7",
        color14 = "94e2d5",
        color15 = "cdd6f4",
    },
}

local function load_wal()
    if not home then return nil end
    local path = home .. "/.cache/wal/colors.json"
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local palette = { colors = {} }
    local special = content:match('"special"%s*:%s*{(.-)}')
    local colors  = content:match('"colors"%s*:%s*{(.-)}')
    if special then
        for k, v in special:gmatch('"(%w+)"%s*:%s*"#([0-9a-fA-F]+)"') do
            palette[k] = v
        end
    end
    if colors then
        for k, v in colors:gmatch('"(color%d+)"%s*:%s*"#([0-9a-fA-F]+)"') do
            palette.colors[k] = v
        end
    end
    if next(palette.colors) == nil then return nil end
    return palette
end

local p = load_wal() or CATPPUCCIN
local bg = p.background
local c  = CATPPUCCIN.colors
local color = function(name) return c[name] or bg end

-- WCAG relative luminance / contrast helpers
local function to_linear(v)
    return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex)
    local function part(offs)
        return to_linear(tonumber(hex:sub(offs, offs + 1), 16) / 255)
    end
    return 0.2126 * part(1) + 0.7152 * part(3) + 0.0722 * part(5)
end

local function contrast(a, b)
    local la, lb = luminance(a), luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- Some wallpapers yield a foreground nearly identical to the background,
-- leaving terminal text almost invisible. Snap such colors to pure white or
-- pure black depending on how light the dominant background is.
local function fix_contrast(hex, min)
    if contrast(hex, bg) >= min then return hex end
    return luminance(bg) < 0.4 and "ffffff" or "000000"
end

local fg       = fix_contrast(p.foreground or p.colors.color7 or "cdd6f4", 4.5)
c.color7       = fix_contrast(c.color7, 3.0) -- plain / dim text
c.color15      = fix_contrast(c.color15, 3.0) -- bold / bright text
c.color6       = fix_contrast(c.color6, 2.0) -- cursor / accents stay visible
c.color4       = fix_contrast(c.color4, 2.0) -- selection highlight stays visible
c.color0       = fix_contrast(c.color0, 2.0) -- black text
c.color8       = fix_contrast(c.color8, 2.0) -- bright black text

local config = {}

-- Fonts: prefer a Nerd Font for icons; fall back to the system default.
-- Install a Nerd Font (e.g. ttf-nerd-fonts-symbols-mono) to enable icons.
config.font_size = 11.0
config.font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "FiraCode Nerd Font",
    "monospace",
})

-- Wal-derived colors
config.colors = {
    foreground        = "#" .. fg,
    background        = "#" .. bg,
    cursor_bg         = "#" .. color("color6"),
    cursor_fg         = "#" .. bg,
    cursor_border     = "#" .. color("color6"),
    selection_bg      = "#" .. color("color4"),
    selection_fg      = "#" .. bg,
    scrollbar_thumb   = "#" .. color("color8"),
    split             = "#" .. color("color8"),

    ansi = {
        "#" .. color("color0"),
        "#" .. color("color1"),
        "#" .. color("color2"),
        "#" .. color("color3"),
        "#" .. color("color4"),
        "#" .. color("color5"),
        "#" .. color("color6"),
        "#" .. color("color7"),
    },
    brights = {
        "#" .. color("color8"),
        "#" .. color("color9"),
        "#" .. color("color10"),
        "#" .. color("color11"),
        "#" .. color("color12"),
        "#" .. color("color13"),
        "#" .. color("color14"),
        "#" .. color("color15"),
    },
}

-- Quality of life
config.enable_wayland = false
config.native_macos_fullscreen_mode = false
config.window_decorations = "RESIZE" -- hide the title bar (Hyprland handles it)
config.window_background_opacity = 0.65
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = "NeverPrompt"
config.scrollback_lines = 10000

return config
