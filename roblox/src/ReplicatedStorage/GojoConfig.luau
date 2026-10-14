-- Shared tuning; all combat decisions are made by Combat.server.luau.
return {
    MaxEnergy = 100, EnergyRegen = 5, MaxHealth = 200,
    -- Skills each character may request; the server rejects anything outside the player's kit.
    Kits = {
        Gojo = { "Blue", "Red", "Domain", "Dash" },
        Zenitsu = { "Breath", "Thunderclap", "FlameGod", "Dash" },
        Reze = { "Rampage", "Kick", "BombDevil", "Detonation", "Dash" },
    },
    Blue = { Cost = 15, Cooldown = 5, Windup = 0.65, Duration = 8, Range = 24, Radius = 14, PullSpeed = 10 },
    Red = { Cost = 20, Cooldown = 6, Windup = 0.45, Damage = 65, Speed = 100, Radius = 3.5, Range = 140 },
    -- Blue and Red are held for up to Hold.Duration before they fire; the other one during the hold makes Purple.
    Hold = { Duration = 3 },
    Purple = {
        Windup = 3.6, Damage = 180, Speed = 105, Radius = 7, Range = 170,
        RiseHeight = 12, RiseDuration = 2.4, MergeAt = 2.85, Recovery = 0.45,
        OrbDistance = 5, ChargeRadius = 0.6, MergedRadius = 1.4, VisualRadius = 3, PierceWorld = true,
    },
    Domain = { Cost = 45, Cooldown = 15, Windup = 2, Duration = 7.5, Radius = 26, Tick = 0.5, Damage = 8 },
    Dash = { Cost = 5, Cooldown = 2.5, Distance = 16 },
    -- Zenitsu: Breath grants Charges instant Thunderclaps (no windup, cost or cooldown) for ChargeWindow seconds.
    Thunderclap = { Cost = 18, Cooldown = 6, Windup = 2, InstantWindup = 0.05, Distance = 36, Width = 5, Damage = 70 },
    Breath = { Cost = 20, Cooldown = 14, Windup = 2, Charges = 3, ChargeWindow = 12 },
    -- Seventh form: a draw-dash ten times faster than Thunderclap. Victims are hit HitDelay after the pass;
    -- the user pays SelfDamage (never lethal) and moves at SlowFactor speed with Dash locked for SlowDuration.
    FlameGod = { DragonScale = 2.5, Cost = 50, Cooldown = 25, Windup = 0.8, Duration = 1.6, Distance = 60, Width = 7, Damage = 150, HitDelay = 0.9, RecoilDelay = 1, SelfDamage = 30, SlowDuration = 4, SlowFactor = 0.4 },
    -- Reze. Human form: only Dash and BombDevil. Pulling the choker pin transforms her with no time limit and heals
    -- Heal of max HP (never past full); Rampage and Kick then work, each costing HpCost of max HP (never lethal).
    -- R again is Detonation: Windup seconds later a huge blast goes off, it costs 12% HP, and she turns human again.
    -- BombDevil can be used again Recharge seconds after she reverts.
    BombDevil = { Cost = 0, Cooldown = 0, Recharge = 20, Windup = 1, Blackout = 2, Heal = 0.2, Radius = 16, Damage = 90, Knockback = 110, Lift = 55 },
    Detonation = { Cost = 0, Cooldown = 0, Windup = 4, HpCost = 0.12, Radius = 30, Damage = 170, Knockback = 130, Lift = 60 },
    -- Rampage: a blast under the feet launches her forward; anyone on the path is blown upward, and the gunpowder
    -- left along the path detonates TrailDelay seconds later.
    Rampage = { Cost = 0, HpCost = 0.03, Cooldown = 5, Windup = 0.12, SlideSpeed = 55, Distance = 30, Width = 5, Damage = 45, Launch = 70, TrailDelay = 1, TrailRadius = 5.5, TrailDamage = 35, TrailLift = 45 },
    -- Kick: a roundhouse. The right foot is raised for most of Windup, then whips right to left. Alone it goes off Reach studs in front of her; used within ComboWindow seconds of
    -- Rampage it continues the Rampage direction as a ComboDistance dash ending in a bigger blast.
    Kick = { Cost = 0, HpCost = 0.03, Cooldown = 4, Windup = 0.38, Reach = 5, Radius = 6, Damage = 45, Knockback = 32, Lift = 28, ComboWindow = 1.3, ComboDistance = 18, Width = 4.5, ComboRadius = 8, ComboDamage = 85, ComboKnockback = 70, ComboLift = 36 },
    Colors = { Blue = Color3.fromRGB(35, 180, 255), Red = Color3.fromRGB(255, 54, 94), Purple = Color3.fromRGB(171, 95, 255), Thunder = Color3.fromRGB(255, 210, 63), Bomb = Color3.fromRGB(255, 122, 46) },
}
