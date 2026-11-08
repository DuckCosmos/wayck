local mainMod  = "SUPER"
local terminal = "kitty"

-- Apps e shell
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd("qs -c wayck ipc call launcher toggle"))
hl.bind(mainMod .. " + V",      hl.dsp.exec_cmd("qs -c wayck ipc call clipboard toggle"))
hl.bind(mainMod .. " + B",		hl.dsp.exec_cmd("qs -c wayck ipc call bar toggle"))
hl.bind(mainMod .. " + T",      hl.dsp.exec_cmd("qs -c wayck kill"))
hl.bind(mainMod .. " + SHIFT +  T",		hl.dsp.exec_cmd("qs -c wayck"))
hl.bind(mainMod .. " + W",		hl.dsp.exec_cmd("brave"))
hl.bind(mainMod .. " + E",		hl.dsp.exec_cmd("xdg-open \"$HOME\""))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -c wayck ipc call wallpaper select"))

-- Janelas
hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + D",         hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))

-- Mídia
hl.bind(mainMod .. " + CTRL + SPACE", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind(mainMod .. " + ALT + N",      hl.dsp.exec_cmd("playerctl next"))
hl.bind(mainMod .. " + ALT + P",      hl.dsp.exec_cmd("playerctl previous"))

-- Screenshot e replay do OBS
hl.bind("CTRL + ALT + RETURN",         hl.dsp.exec_cmd("qs -c wayck ipc call screenshot full"))
hl.bind("CTRL + SHIFT + ALT + RETURN", hl.dsp.exec_cmd("qs -c wayck ipc call screenshot region"))
hl.bind("CTRL + SHIFT + ALT + S + RETURN", hl.dsp.exec_cmd("qs -c wayck ipc call screenshot regionOCR"))

-- Foco
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-9: ir e mover janela
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Scroll do mouse
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ direction = "left" }),  { mouse = true })
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ direction = "right" }), { mouse = true })
hl.bind(mainMod .. " + mouse_down",         hl.dsp.focus({ workspace = "+1" }),    { mouse = true })
hl.bind(mainMod .. " + mouse_up",           hl.dsp.focus({ workspace = "-1" }),    { mouse = true })

-- Mouse: SUPER + botão esquerdo move, direito redimensiona
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
