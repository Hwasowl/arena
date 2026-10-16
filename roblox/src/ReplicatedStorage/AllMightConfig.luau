-- All Might tuning. Read by AllMightServer (every combat decision), AllMightClient and AllMightVFX (timing of the
-- visuals). Times are seconds from the key press unless noted; distances are studs.
return {
    Kit = { "OneForAll", "UnitedStatesOfSmash", "PlusUltra" },
    Colors = {
        Gold = Color3.fromRGB(255, 206, 64), GoldDeep = Color3.fromRGB(232, 150, 30), Spark = Color3.fromRGB(255, 236, 140),
        Wind = Color3.fromRGB(236, 244, 255), Blue = Color3.fromRGB(46, 84, 196), BlueDeep = Color3.fromRGB(26, 46, 120),
        Red = Color3.fromRGB(206, 34, 44), White = Color3.fromRGB(246, 246, 242), Glove = Color3.fromRGB(250, 204, 40),
        Skin = Color3.fromRGB(240, 196, 160), Hair = Color3.fromRGB(255, 220, 70), Dust = Color3.fromRGB(176, 166, 150),
        Rock = Color3.fromRGB(118, 110, 100), Steam = Color3.fromRGB(240, 240, 240), Speed = Color3.fromRGB(150, 196, 255),
    },
    -- Q: a self-buff. Prep (both fists clenched, chest opens) is the only vulnerable part; the buff starts at Prep.
    OneForAll = {
        Cooldown = 25, Prep = 0.85, Open = 0.45, Duration = 10,
        PrepSpeed = 0.12,             -- walk speed factor while clenching (jump locked)
        MoveSpeed = 1.35, BasicDamage = 1.25, SmashDamage = 1.2, BasicKnockback = 1.2,
        DamageTaken = 0.85,           -- incoming damage factor while the buff lasts
        LightKnockback = 45,          -- knockbacks below this speed are ignored, stronger ones keep HeavyKeep of their force
        HeavyKeep = 0.8,
        FatigueFactor = 0.85, FatigueDuration = 1.2,
    },
    -- E: crouch, dash, wind up, full-body punch. Damage is applied once per target per cast.
    UnitedStatesOfSmash = {
        Cooldown = 18, WhiffCooldown = 9, BumpCooldown = 6,
        Crouch = 0.4, DashEnd = 0.75, WindEnd = 1.05, Impact = 1.18, PunchEnd = 1.35,
        Hold = 0.35, Return = 0.3, SlowFactor = 0.7, SlowDuration = 0.8,
        DashDistance = 22, ContactReach = 5, PathWidth = 3.6, StopDistance = 3.2,
        Damage = 55, Knockback = 30, KnockLift = 6, KnockTime = 0.55, WallDamage = 8,
        ShockRadius = 12, ShockDamage = 18, ShockKnock = 9, ShockLift = 14,
        RCancelFrom = 0.12,           -- seconds after Impact: R may cancel the follow-through (E -> R)
    },
    -- R: the whole sequence. Phases after the dash are measured from the moment the dash connects (Contact),
    -- so a close target does not wait for an empty dash; with a full-length dash Contact is 1.15 s.
    PlusUltra = {
        Cooldown = 85, FailCooldown = 30,
        Windup = 0.65, DashTime = 0.5, DashDistance = 35, PathWidth = 4.2, ContactReach = 4.5, StopDistance = 3.4,
        FailDistance = 0.6,           -- an empty dash stops at this fraction of DashDistance with a stumble
        WindupSpeed = 0.15,
        -- relative to Contact
        Punch1 = 0.08, Lift = 0.4, ChaseEnd = 1.35, Punch2 = 1.15, WindEnd = 2.05, Uppercut = 2.12,
        Launch = 2.12, Apex = 3.62, Settle = 3.85, End = 5.05,
        Damage1 = 20, Damage2 = 15, Damage3 = 75, ShockRadius = 18, ShockDamage = 25, ShockHeight = 30,
        LiftHeight = 9, ChaseHeight = 22, CasterChase = 17, ApexHeight = 140, FallMin = 0.9, KnockedDown = 0.6,
        LandAt = 2.95,                -- relative to Contact: the caster is back on the ground
    },
}
