-- Reverse technique is a heal with a real offensive tradeoff. Every skill is independent.
return {
    Kit={"ReverseCursed","RikaStrike","PureLove"},
    ReverseCursed={Cost=30,Cooldown=22,Windup=1.15,Duration=1.8,Heal=.5,WeakenDuration=10,DamageFactor=.7},
    RikaStrike={Cost=20,Cooldown=9,Windup=.58,Commit=.14,Recovery=.67,Range=5,AimAngle=36,Damage=28,Knockback=16,Lift=3},
    PureLove={Cost=55,Cooldown=38,Windup=3.1,LockAt=2.4,Duration=4.6,Range=120,Width=7,Damage=110},
    Colors={Aura=Color3.fromRGB(220,108,196),Heal=Color3.fromRGB(112,255,203),Bone=Color3.fromRGB(202,197,207),Ink=Color3.fromRGB(22,15,31),Gold=Color3.fromRGB(242,207,117)},
}
