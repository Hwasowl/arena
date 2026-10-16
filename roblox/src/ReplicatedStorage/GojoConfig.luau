-- Shared tuning; all combat decisions are made by Combat.server.luau.
return {
    MaxEnergy = 100, EnergyRegen = 5, MaxHealth = 200,
    -- Shared mouse attack: wind back, contact, then recover. One target per hit; third hit pushes it away.
    BasicAttack = { Windups = { 0.16, 0.18, 0.24 }, Swing = 0.1, Recoveries = { 0.22, 0.24, 0.32 }, Damages = { 12, 14, 20 }, Reach = 6, Width = 2.4, ComboReset = 0.95, Knockback = 24, Lift = 8 },
    -- First cut draws from the saya; four slower cuts alternate right/left before an idle resheath.
    ZenBasicAttack = { Windups = { 0.52, 0.32, 0.32, 0.32 }, Swing = 0.24, Recoveries = { 0.30, 0.28, 0.28, 0.34 }, Damages = { 12, 14, 16, 20 }, Reach = 6, Width = 2.4, ComboReset = 0.70, Knockback = 24, Lift = 8, Sheath = 0.42 },
    -- Ctrl while moving on the ground. Horizontal force only, so gravity and jumping still work.
    Slide = { Cost = 6, Cooldown = 1.4, Duration = 0.7, StartSpeed = 38, EndSpeed = 12, MinSpeed = 3, CameraDip = 1.1 },
    -- Skills each character may request; the server rejects anything outside the player's kit.
    Kits = {
        Kizaru = {"LightLaser","LightKick","LightJewels","LightMirror"},
        Okkotsu = { "ReverseCursed", "RikaStrike", "PureLove", "Dash" },
        Gojo = { "Blue", "Red", "Domain", "Dash" },
        Zenitsu = { "Breath", "Thunderclap", "FlameGod", "Dash" },
        Reze = { "Rampage", "Kick", "BombDevil", "Detonation", "Dash" },
        Shanks = { "Haki", "EnGarde", "DivineDeparture", "Dash" },
        Doraemon = { "Pocket", "BambooCopter", "AnywhereDoor", "Dash" },
        -- Tendo Pain: tuning and judgement live in PainAbilityConfig / PainServer.
        Pain = { "ShinraTensei", "BanshoTenin", "ChibakuTensei", "Dash" },
        -- All Might: tuning and judgement live in AllMightConfig / AllMightServer.
        AllMight = { "OneForAll", "UnitedStatesOfSmash", "PlusUltra", "Dash" },
    },
    LightLaser = {Cost=15,Cooldown=5,Windup=.65,Duration=1.05,Damage=42,Range=90,Width=.8},
    LightKick = {Cost=24,Cooldown=8,Windup=.3,Duration=1.1,Damage=65,Range=48,Width=4.5},
    LightJewels = {Cost=55,Cooldown=28,Windup=.5,Duration=2.9,Damage=12,Range=90,Width=1.25,Height=26,Rise=.45,Hover=2.25,Fall=.5,Shoot=.95,Gap=.085},
    LightMirror = {Cost=12,Cooldown=6,Windup=.45,Duration=.85,Range=24},
    Blue = { Cost = 15, Cooldown = 5, Windup = 0.65, Duration = 8, Range = 24, Radius = 14, PullSpeed = 10 },
    Red = { Cost = 20, Cooldown = 6, Windup = 0.45, Damage = 65, Speed = 100, Radius = 3.5, WorldRadius = 1.2, Range = 140 },
    -- Blue and Red are held for up to Hold.Duration before they fire; the other one during the hold makes Purple.
    Hold = { Duration = 3 },
    Purple = {
        Windup = 3.6, Damage = 180, Speed = 105, Radius = 7, Range = 170,
        RiseHeight = 12, RiseDuration = 2.4, MergeAt = 2.85, Recovery = 0.45,
        OrbDistance = 5, ChargeRadius = 0.6, MergedRadius = 1.4, VisualRadius = 3, PierceWorld = true,
    },
    Domain = { Cost = 45, Cooldown = 15, Windup = 2, Duration = 7.5, Radius = 26, Tick = 0.5, Damage = 8, ClashWindow = 0.75 },
    Dash = { Cost = 5, Cooldown = 2.5, Distance = 16 },
    -- Every E keeps the same hold time and 10–40 stud range. Breath grants three separately charged consecutive uses.
    Thunderclap = { Cost = 18, Cooldown = 6, ChainCooldown = 0.5, Windup = 0.05, MaxCharge = 1.6, MinDistance = 10, Distance = 40, Width = 5, Damage = 70 },
    Breath = { Cost = 20, Cooldown = 14, Windup = 2, Charges = 3, ChargeWindow = 12 },
    -- Seventh form: a draw-dash ten times faster than Thunderclap. Victims are hit HitDelay after the pass;
    -- the user pays SelfDamage (never lethal) and moves at SlowFactor speed with Dash locked for SlowDuration.
    FlameGod = { DragonScale = 2.5, Cost = 50, Cooldown = 25, Windup = 0.8, Duration = 1.6, Distance = 60, Width = 7, Damage = 150, HitDelay = 0.9, RecoilDelay = 1, SelfDamage = 30, SlowDuration = 4, SlowFactor = 0.4 },
    -- Reze. Q: crouch, blast upward, then press Q again during AirWindow to dive and slam. E raises the right hand
    -- for a close forward blast. Each costs HpCost of max HP (never lethal). R starts the original moving fuse.
    -- BombDevil can be used again Recharge seconds after she reverts.
    BombDevil = { Cost = 0, Cooldown = 0, Recharge = 20, Windup = 1, Blackout = 2, Heal = 0.2, Radius = 16, Damage = 90, Knockback = 110, Lift = 55 },
    Detonation = { Cost = 0, Cooldown = 0, Windup = 4, HpCost = 0.12, Radius = 30, Damage = 170, Knockback = 130, Lift = 60, SlowAtEnd = 0.25,
        RecoilSpeed = 40, RecoilLift = 30, RecoilAirLimit = 1.4, SkidSpeed = 30, SkidDuration = 0.7, StandDuration = 0.3 },
    -- Shanks: Haki guarantees two 10-damage pulses in a 10-stud radius. EnGarde opens a short
    -- two-choice window: left click lunges; right click guards for one second and ripostes only if hit.
    Haki = { Cost = 20, Cooldown = 14, Windup = 0.5, Radius = 10, Damage = 10, Tick = 1, Pulses = 2 },
    EnGarde = { Cost = 12, Cooldown = 8, Window = 3, ParryWindow = 1, SlashDamage = 35, SlashDistance = 10, SlashWidth = 3.5, CounterDamage = 45, CounterReach = 12 },
    DivineDeparture = { Cost = 40, Cooldown = 20, Windup = 2.5, Damage = 50, Distance = 50, Width = 5 },
    -- Q is a two-step move: crouch for .4s and rise on a foot blast; Q again in AirWindow dives to the floor.
    Rampage = { Cost = 0, HpCost = 0.03, Cooldown = 5, Windup = 0.4, AirWindow = 2.5, RiseSpeed = 124, RiseForwardSpeed = 24, DiveSpeed = 100, SlamDelay = 0.04, Radius = 9, Damage = 65, Knockback = 40, Lift = 34 },
    -- E: hold the right hand up for .2s, then make a close-range explosion three studs ahead.
    Kick = { Cost = 0, HpCost = 0.03, Cooldown = 4, Windup = 0.2, Fuse = 0.8, Reach = 3, Radius = 3.5, Damage = 55, Knockback = 38, Lift = 22 },
    Pocket = { Cost = 12, Cooldown = 5, Windup = 1.75, DrawTime = 0.98, Recovery = 0.45, Range = 42, ShrinkDuration = 2, ShrinkScale = 0.6,
        CannonDamage = 10, CannonWallDamage = 30, CannonDistance = 20, CannonTime = 0.38, Heal = 20 },
    BambooCopter = { Cost = 18, Cooldown = 12, Windup = 2.05, Recovery = 0.35, Duration = 3, FlySpeed = 24, VerticalSpeed = 15 },
    AnywhereDoor = { Cost = 28, Cooldown = 18, Windup = 2.3, Recovery = 0.35, Distance = 24 },
    Colors = { Dora = Color3.fromRGB(48, 166, 221), Blue = Color3.fromRGB(35, 180, 255), Red = Color3.fromRGB(255, 54, 94), Purple = Color3.fromRGB(171, 95, 255), Thunder = Color3.fromRGB(255, 210, 63), Bomb = Color3.fromRGB(255, 122, 46), Haki = Color3.fromRGB(255, 45, 67) },
}
