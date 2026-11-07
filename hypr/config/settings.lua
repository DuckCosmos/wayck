hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 6,
        border_size = 1,
        layout      = "dwindle",
    },

    decoration = {
        rounding = 6,
        -- Blur desligado por padrão. O Wayck liga em tempo de execução se o
        -- usuário escolheu blur na instalação; recarregar o Hyprland desfaz isso.
        blur   = { enabled = false },
        shadow = { enabled = false },
    },

    animations = { enabled = true },

    input = {
        kb_layout      = "us",
        kb_variant     = "intl",
        follow_mouse   = 1,
        accel_profile  = "flat",
        sensitivity    = 0.0,
        scroll_factor  = 1.0,
    },

    binds = {
        scroll_event_delay = 0,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },
})
