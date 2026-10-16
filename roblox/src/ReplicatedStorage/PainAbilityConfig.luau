-- Tendo Pain tuning. Read by PainServer (all combat decisions), PainClient and PainVFX (timing of the visuals).
-- Every time below is seconds from the key press; distances are studs.
return {
    Kit = { "ShinraTensei", "BanshoTenin", "ChibakuTensei" },
    Colors = {
        Rinnegan = Color3.fromRGB(176, 132, 255), RinneganDeep = Color3.fromRGB(92, 58, 168),
        Cloud = Color3.fromRGB(196, 28, 40), CloudRim = Color3.fromRGB(245, 244, 240),
        Sleeve = Color3.fromRGB(14, 14, 18), Nail = Color3.fromRGB(10, 10, 14), Skin = Color3.fromRGB(226, 190, 168),
        Rock = Color3.fromRGB(112, 104, 96), Dust = Color3.fromRGB(158, 150, 140),
    },
    -- Q: palm raised and opened finger by finger until Windup, the push releases a sphere that sweeps Radius in
    -- WaveTime. Each victim is hit when the front reaches it, once per cast.
    ShinraTensei = {
        Cooldown = 12, Windup = 0.45, WaveTime = 0.25, Radius = 25, Damage = 30,
        KnockMin = 18, KnockMax = 35, LiftMin = 3, LiftMax = 7, FlightTime = 0.6, WallDamage = 5,
        CastSpeed = 0.25,          -- walk speed factor while the palm opens (jump and dash locked)
        Recovery = 0.7,            -- defenceless after the push: no skills, still slowed
        SlowDuration = 1.5, SlowFactor = 0.75,
        ProjectileKinds = { Red = true },   -- small projectiles the wave erases (Hollow Purple is too big)
    },
    -- E: the camera ray picks one visible target within Range and AimAngle; it is dragged to StopDistance in front
    -- of Pain, then the left hand stabs it with a chakra receiver.
    BanshoTenin = {
        Cooldown = 14, MissCooldown = 1.5, Range = 55, AimAngle = 12, Windup = 0.35,
        PullTimeMax = 0.8, PullTimeMin = 0.38, StopDistance = 4, Lift = 1.6, LeashRange = 62,
        StrikeDelay = 0.14, StrikeDamage = 25, StrikeKnock = 6, StrikeKnockTime = 0.2, Stun = 0.5,
        MissRecovery = 0.35, Recovery = 0.4,
    },
    -- R: the full 6.5 s sequence. Field and capture use the horizontal distance to the point under the core.
    ChibakuTensei = {
        Cooldown = 80, Duration = 6.5,
        Gather = 0.8, Launch = 1.5, CoreForward = 20, CoreHeight = 45, Radius = 45,
        FieldStart = 1.5, LiftStart = 2.0, DebrisStart = 2.5, Formed = 4.5, CompressEnd = 5.5, Burst = 5.6,
        CaptureMax = 4, TickTimes = { 2.5, 3.5 }, TickDamage = 10, FinalDamage = 55,
        SphereRadius = 13, SealRadius = 5.5, GroundSlow = 0.4,
        DamageTaken = 0.7, SlowDuration = 1, SlowFactor = 0.6, KnockedDown = 0.8,
        Rocks = 64, CraterTime = 7,
    },
}
