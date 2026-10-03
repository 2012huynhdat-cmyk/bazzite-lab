hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({
    input = { kb_layout = "fr", follow_mouse = 1 },
    general = { gaps_in = 5, gaps_out = 12, border_size = 2, layout = "dwindle" },
    decoration = { rounding = 8 },
})
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm finalize")
    hl.exec_cmd("bazzite-lab-shell")
end)
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("uwsm stop"))
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("bazzite-lab-lock"))
hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + M", hl.dsp.exec_cmd("hyprmod"))
