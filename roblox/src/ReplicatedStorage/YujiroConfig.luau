-- Yujiro Hanma tuning. Read by YujiroServer (every combat decision), YujiroClient and YujiroVFX (timing of the
-- visuals). Times are seconds from the key press (Q: from the read for the counter itself) unless noted; distances are
-- studs. The browser preview (preview/yujiro.js) uses the same numbers.
return {
    Kit = { "OgreCounter", "OgreRush", "OgreJudgment" },
    Colors = {
        Skin = Color3.fromRGB(214, 150, 112), SkinDeep = Color3.fromRGB(176, 108, 78), Muscle = Color3.fromRGB(196, 128, 92),
        Shadow = Color3.fromRGB(92, 44, 34), Vein = Color3.fromRGB(150, 62, 54), Nail = Color3.fromRGB(232, 196, 170),
        Hair = Color3.fromRGB(196, 22, 24), HairDeep = Color3.fromRGB(120, 10, 14), Red = Color3.fromRGB(255, 50, 40),
        Pressure = Color3.fromRGB(150, 20, 20), White = Color3.fromRGB(250, 248, 244), Dust = Color3.fromRGB(176, 166, 150),
        Rock = Color3.fromRGB(118, 110, 100), Crack = Color3.fromRGB(34, 30, 28),
    },
    -- Q 지상 최강의 생물: a counter stance. Damage kinds a read can answer; everything else (Projectile, DoT, fields,
    -- shockwaves, explosions, ultimates) can never be countered. Projectiles still lose the frontal reduction.
    OgreCounter = {
        Cooldown = 18,
        Entry = 0.25,                 -- stance entry; the window opens here
        WindowEnd = 2.5,              -- no read by now: failure
        Arc = 80,                     -- frontal half-angle in degrees (160 degrees in all)
        Reduction = 0.7,              -- frontal hits lose 70% while waiting
        Counterable = { Basic = true, Melee = true, Weapon = true, Dash = true, Kick = true },
        -- relative to the read
        Snap = 0.15, Hit = 0.30, PunchEnd = 0.5, End = 0.9,
        Damage = 30, Knockback = 12, KnockLift = 3, KnockTime = 0.35, Stagger = 0.8,
        Reach = 9,                    -- the uppercut lands if the attacker is still this close at the hit
        StepTo = 2.6,                 -- the caster steps in to this distance in front of the attacker (never through walls)
        StepMax = 6,
        Slowdown = 0.06,              -- client-only visual slowdown on the read
        BuffDuration = 0.5, BasicDamage = 1.15,   -- after a successful counter (from the end of the cast)
        FailRecovery = 0.4, FailEnd = 2.9, FailSpeed = 0.45,
    },
    -- E 오거 러시: crouch, dash, body blow, hook, axe kick on one held target. 10 + 15 + 20 = 45 at most.
    OgreRush = {
        Cooldown = 15,
        Crouch = 0.2, DashEnd = 0.5, Distance = 18, Width = 2.2, Stop = 2.25, Escape = 5.3,
        BodyEnd = 0.7, HookEnd = 0.95, AxeEnd = 1.35, End = 1.75,
        WhiffEnd = 0.85,              -- nobody linked: a short stumble, then the cast ends
        Blows = {
            { Time = 0.62, Damage = 10, Kind = "Melee", Name = "Body" },
            { Time = 0.84, Damage = 15, Kind = "Melee", Name = "Hook" },
            { Time = 1.21, Damage = 20, Kind = "Kick", Name = "Axe" },
        },
    },
    -- R 오거의 심판. 15 + 15 + 4 x 5 + 50 = 100 at most; every hit is "Ultimate" and lands at most once.
    OgreJudgment = {
        Cooldown = 90, FailCooldown = 30,
        Serious = 0.5, Open = 1.0, Capture = 1.0, FailEnd = 1.55,
        Range = 25, Angle = 15,
        DashEnd = 1.5, Hold = 2.2,    -- the caster reaches the target and grabs it at this distance
        Hits = {
            { Time = 1.66, Damage = 15, Name = "Body" },
            { Time = 2.05, Damage = 15, Name = "Slap" },
            { Time = 2.40, Damage = 5, Name = "Rush" },
            { Time = 2.56, Damage = 5, Name = "Rush" },
            { Time = 2.72, Damage = 5, Name = "Rush" },
            { Time = 2.88, Damage = 5, Name = "Rush" },
            { Time = 4.12, Damage = 50, Name = "Final" },
        },
        LiftFrom = 3.0, LiftTo = 3.5, LiftHeight = 3,
        Release = 3.62, ThrowDistance = 4.5, ThrowHeight = 1.2,
        WindFrom = 3.5, WindTo = 4.0, Final = 4.12, Hitstop = 0.08, StepIn = 1.6,
        Down = 0.8,                   -- the target lies on the floor this long after the final punch lands
        End = 5.5,
        DamageTaken = 0.7,            -- the caster takes 30% less for the whole cast
    },
    -- Placeholder sounds (built-in assets); replace with uploaded ids.
    Sounds = {
        Laugh = { id = "rbxasset://sounds/action_falling.mp3", speed = 0.32 },
        Parry = { id = "rbxasset://sounds/electronicpingshort.mp3", speed = 0.7 },
        Swing = { id = "rbxasset://sounds/swordslash.wav", speed = 0.5 },
        Punch = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.7 },
        Heavy = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.42 },
        Slap = { id = "rbxasset://sounds/impact_generic.mp3", speed = 1.25 },
        Boom = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.3 },
        Heartbeat = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.36 },
        Dash = { id = "rbxasset://sounds/swordslash.wav", speed = 0.75 },
        Thud = { id = "rbxasset://sounds/impact_generic.mp3", speed = 0.85 },
    },
}
