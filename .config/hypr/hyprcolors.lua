-- hyprcolors.lua
-- Wal-based palette for the Hyprland Lua config.
-- Reads ~/.cache/wal/colors.json (written by pywal16) and derives theme colors.
-- Falls back to Catppuccin Mocha when the palette file is unavailable.

local home = os.getenv("HOME") or os.getenv("USERPROFILE")

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
local bg    = p.background
local c     = p.colors
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

-- Some wallpapers yield colors nearly identical to the background; snap
-- them to pure white or pure black so text and borders stay visible.
local function fix_contrast(hex, min)
    if contrast(hex, bg) >= min then return hex end
    return luminance(bg) < 0.4 and "ffffff" or "000000"
end

local fg     = fix_contrast(p.foreground or p.colors.color7 or "cdd6f4", 4.5)
c.color7     = fix_contrast(c.color7, 3.0)
c.color15    = fix_contrast(c.color15, 3.0)
c.color6     = fix_contrast(c.color6, 2.0) -- active border / accents stay visible
c.color4     = fix_contrast(c.color4, 2.0)
c.color0     = fix_contrast(c.color0, 2.0)
c.color8     = fix_contrast(c.color8, 2.0)

local M = {}

M.bg = "#" .. bg
M.fg = "#" .. fg

M.active_border   = { "rgba(" .. color("color6") .. "ee)", "rgba(" .. color("color4") .. "ee)" }
M.inactive_border = "rgba(" .. color("color8") .. "aa)"
M.shadow          = 0xee000000 + tonumber(bg, 16)
M.alpha_bg        = "rgba(" .. bg .. "ee)"

return M
