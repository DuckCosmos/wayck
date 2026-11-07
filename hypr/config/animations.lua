
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.5, bezier = "easeOutQuint",   style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3,   bezier = "quick",          style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,   bezier = "easeInOutCubic" })

hl.animation({ leaf = "fade",   enabled = true, speed = 3, bezier = "almostLinear" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "easeOutQuint" })

hl.animation({ leaf = "layersIn",  enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.5, bezier = "quick",        style = "fade" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade 20%" })
