-- Uchiha Itachi tuning. Read by ItachiServer (every combat decision), ItachiClient and ItachiVFX (timing of the
-- visuals). Times are seconds from the key press (or from the dodge) unless noted; distances are studs.
return {
    Kit = { "Tsukuyomi", "Amaterasu", "Susanoo" },
    Colors = {
        Red = Color3.fromRGB(255, 42, 36), Crimson = Color3.fromRGB(150, 8, 12), Blood = Color3.fromRGB(70, 0, 4),
        Black = Color3.fromRGB(6, 4, 6), Ash = Color3.fromRGB(70, 66, 66), Ember = Color3.fromRGB(255, 70, 40),
        Gold = Color3.fromRGB(255, 196, 96), Cloak = Color3.fromRGB(14, 12, 18), Cloud = Color3.fromRGB(196, 18, 28),
        CloudRim = Color3.fromRGB(240, 236, 236), Skin = Color3.fromRGB(236, 206, 180), Nail = Color3.fromRGB(96, 70, 128),
        Crow = Color3.fromRGB(10, 10, 14), Moon = Color3.fromRGB(200, 10, 16),
    },
    -- Passive: rolled on the server before a dodgeable hit lands. A dodge cancels the whole hit (no damage, no
    -- knockback); it never chains with itself because the internal cooldown starts on the dodge.
    CrowClone = {
        Chance = 0.2, InternalCooldown = 25, Distance = 12, SideStep = 8,
        Break = 0.1, MoveFrom = 0.25, MoveTo = 0.45, Reform = 0.65, Total = 0.85,
        ClearRadius = 3,              -- no character may stand this close to the landing spot
        -- Hit kinds the clone can dodge. Everything else (DoT, status, genjutsu, shockwaves, explosions, environment,
        -- falls, and ultimates flagged "Ultimate") always lands. An unlabelled hit is treated as undodgeable.
        Dodgeable = { Basic = true, Melee = true, Kick = true, Weapon = true, Dash = true, Projectile = true },
    },
    -- Q: one target in a 12-degree cone, 35 studs, in sight. The victim's own client shows the genjutsu world.
    Tsukuyomi = {
        Cooldown = 16, FailCooldown = 1.5, Range = 35, Angle = 12, Damage = 12,
        Prep = 0.3, Eye = 0.55, World = 0.9, Wave = 1.35, Crack = 1.5, End = 1.95,
        Bind = 1.4,                   -- Eye .. End: no move, jump, dash or skills
        CasterSpeed = 0.35, Busy = 1.5,
    },
    -- E: the point the screen centre looks at on valid ground. Black flames, never orange.
    Amaterasu = {
        Cooldown = 20, FailCooldown = 1, Range = 65, MaxSlope = 35,
        StartRadius = 3, Radius = 20, FlameHeight = 5, StepHeight = 6,
        Ignite = 0.55, Spread = 0.8, Full = 1.5, BurnEnd = 6, Gone = 6.7,
        EntryDamage = 10, TickDamage = 6, Tick = 1, MaxTicks = 5,        -- 10 + 5 x 6 = 40 per target at most
        Slow = 0.8, CasterSpeed = 0.5, Busy = 0.85,
    },
    -- R: Susanoo forms around the caster, the Yata Mirror guards the front, the Totsuka Blade thrusts and seals.
    Susanoo = {
        Cooldown = 90,
        Ribs = 0.6, Upper = 1.1, Mirror = 1.8, Blade = 2.5, Aim = 3.2, Thrust = 3.65, Tip = 3.9, StrikeEnd = 4.15,
        Seal = 4.6, SealHit = 5.0, SealEnd = 5.35, MirrorBreak = 5.5, End = 6.4, SealFor = 1.8,
        Reach = 35, Width = 4, Damage1 = 55, Damage2 = 25,
        MirrorReduction = 0.6, MirrorArc = 75,           -- frontal half-angle in degrees
        Height = 14, Hand = Vector3.new(5.5, 6, -3.5),   -- right hand relative to the caster's root (studs)
        LiftHeight = 3, SealPoint = 0.55,                -- the victim is drawn to this fraction of the blade
    },
    -- Placeholder sounds (built-in assets); replace with uploaded ids.
    Sounds = {
        Caw = { id = "rbxasset://sounds/electronicpingshort.mp3", speed = 1.9 },
        Flutter = { id = "rbxasset://sounds/swordslash.wav", speed = 1.6 },
        Eye = { id = "rbxasset://sounds/electronicpingshort.mp3", speed = 0.55 },
        Genjutsu = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.3 },
        Wave = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.6 },
        Crack = { id = "rbxasset://sounds/impact_generic.mp3", speed = 1.4 },
        Ignite = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.55 },
        Burn = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.35 },
        Hum = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.22 },
        Mirror = { id = "rbxasset://sounds/electronicpingshort.mp3", speed = 0.4 },
        Thrust = { id = "rbxasset://sounds/swordslash.wav", speed = 0.5 },
        Impact = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.45 },
        Seal = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.6 },
    },
}
