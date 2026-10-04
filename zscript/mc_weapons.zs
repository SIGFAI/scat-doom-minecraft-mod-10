// SuperIntelligent Cat - Doom's arsenal, Minecraft edition. Same slots and ammo as Doom:
// 1 diamond sword / diamond pickaxe, 2 bow, 3 crossbow / multishot crossbow, 4 dispenser, 5 TNT,
// 6 fire charges, 7 the Cat's fish (it is very upset about it).

class MCSword : Fist replaces Fist
{
	Default
	{
		Weapon.SlotNumber 1;
		Weapon.Kickback 120;
		Tag "Diamond Sword";
		Inventory.PickupMessage "Diamond Sword!";
		+WEAPON.MELEEWEAPON
	}
	States
	{
	Ready:
		MSWD A 1 A_WeaponReady;
		Loop;
	Deselect:
		MSWD A 1 A_Lower;
		Loop;
	Select:
		MSWD A 1 A_Raise;
		Loop;
	Fire:
		MSWD B 2 A_StartSound("mc/sword", CHAN_WEAPON);
		MSWD C 2 A_CustomPunch(random(22, 36), true, 0, "MCHitPuff", 84, 0, 0, "", "mc/swordhit", "");
		MSWD C 4;
		MSWD B 3;
		MSWD A 4 A_ReFire;
		Goto Ready;
	Spawn:
		WSWD A -1;
		Stop;
	}
}

class MCPickaxe : Chainsaw replaces Chainsaw
{
	Default
	{
		Weapon.SlotNumber 1;
		Weapon.ReadySound "";
		Weapon.Kickback 60;
		Tag "Diamond Pickaxe";
		Inventory.PickupMessage "Diamond Pickaxe! Mining time.";
	}
	States
	{
	Ready:
		MPCK A 1 A_WeaponReady;
		Loop;
	Deselect:
		MPCK A 1 A_Lower;
		Loop;
	Select:
		MPCK A 1 A_Raise;
		Loop;
	Fire:
		MPCK B 2 A_StartSound("mc/pickaxe", CHAN_WEAPON);
		MPCK C 2 A_CustomPunch(random(12, 22), true, 0, "MCHitPuff", 80, 0, 0, "", "mc/pickaxe", "");
		MPCK B 2;
		MPCK A 2 A_ReFire;
		Goto Ready;
	Spawn:
		WPCK A -1;
		Stop;
	}
}

class MCBow : Pistol replaces Pistol
{
	Default
	{
		Weapon.SlotNumber 2;
		Tag "Bow";
		Inventory.PickupMessage "Bow!";
	}
	States
	{
	Ready:
		MBOW A 1 A_WeaponReady;
		Loop;
	Deselect:
		MBOW A 1 A_Lower;
		Loop;
	Select:
		MBOW A 1 A_Raise;
		Loop;
	Fire:
		MBOW B 3 A_StartSound("mc/bowpull", CHAN_WEAPON);
		MBOW C 3;
		MBOW D 4;
		MBOW A 2 { A_FireProjectile("MCPlayerArrow", 0, true); A_StartSound("mc/bowshot", CHAN_WEAPON); }
		MBOW A 3 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WBOW A -1;
		Stop;
	}
}

class MCCrossbow : Shotgun replaces Shotgun
{
	Default
	{
		Weapon.SlotNumber 3;
		Tag "Crossbow";
		Inventory.PickupMessage "Crossbow! Multishot III.";
	}
	States
	{
	Ready:
		MXBW A 1 A_WeaponReady;
		Loop;
	Deselect:
		MXBW A 1 A_Lower;
		Loop;
	Select:
		MXBW A 1 A_Raise;
		Loop;
	Fire:
		MXBW B 2
		{
			A_FireProjectile("MCPlayerBolt", -5, true);
			A_FireProjectile("MCPlayerBolt", 0, false);
			A_FireProjectile("MCPlayerBolt", 5, false);
			A_StartSound("mc/bowshot", CHAN_WEAPON);
		}
		MXBW B 8;
		MXBW C 8 A_StartSound("mc/bowpull", CHAN_WEAPON);
		MXBW D 8;
		MXBW A 6 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WXBW A -1;
		Stop;
	}
}

class MCMultishot : SuperShotgun replaces SuperShotgun
{
	Default
	{
		Weapon.SlotNumber 3;
		Tag "Enchanted Crossbow";
		Inventory.PickupMessage "Enchanted Crossbow! Multishot VII. Totally legit.";
	}
	States
	{
	Ready:
		MXB2 A 1 A_WeaponReady;
		Loop;
	Deselect:
		MXB2 A 1 A_Lower;
		Loop;
	Select:
		MXB2 A 1 A_Raise;
		Loop;
	Fire:
		MXB2 B 3
		{
			for (int i = -3; i <= 3; i++) A_FireProjectile("MCPlayerBolt", i * 3.5, i == -3);
			A_StartSound("mc/bowshot", CHAN_WEAPON);
			A_StartSound("mc/tntshot", CHAN_7);
		}
		MXB2 B 10;
		MXB2 C 10 A_StartSound("mc/bowpull", CHAN_WEAPON);
		MXB2 D 10;
		MXB2 A 6 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WXB2 A -1;
		Stop;
	}
}

class MCDispenser : Chaingun replaces Chaingun
{
	Default
	{
		Weapon.SlotNumber 4;
		Tag "Dispenser";
		Inventory.PickupMessage "A Dispenser! It's a block that shoots arrows. Obviously.";
	}
	States
	{
	Ready:
		MDSP A 1 A_WeaponReady;
		Loop;
	Deselect:
		MDSP A 1 A_Lower;
		Loop;
	Select:
		MDSP A 1 A_Raise;
		Loop;
	Fire:
		MDSP B 2 { A_FireProjectile("MCPlayerArrow", frandom(-2.5, 2.5), true, 0, 4); A_StartSound("mc/dispense", CHAN_WEAPON); }
		MDSP A 2;
		MDSP B 2 { A_FireProjectile("MCPlayerArrow", frandom(-2.5, 2.5), true, 0, 4); A_StartSound("mc/dispense", CHAN_WEAPON); }
		MDSP A 2 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WDSP A -1;
		Stop;
	}
}

class MCTNTCannon : RocketLauncher replaces RocketLauncher
{
	Default
	{
		Weapon.SlotNumber 5;
		Tag "TNT";
		Inventory.PickupMessage "TNT! Throw responsibly.";
	}
	States
	{
	Ready:
		MTNT A 1 A_WeaponReady;
		Loop;
	Deselect:
		MTNT A 1 A_Lower;
		Loop;
	Select:
		MTNT A 1 A_Raise;
		Loop;
	Fire:
		MTNT B 4;
		MTNT B 2 A_FireProjectile("MCPlayerTNT", 0, true);
		TNT1 A 8;
		MTNT A 6 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WTNT A -1;
		Stop;
	}
}

class MCFireChargeGun : PlasmaRifle replaces PlasmaRifle
{
	Default
	{
		Weapon.SlotNumber 6;
		Tag "Fire Charges";
		Inventory.PickupMessage "Fire Charges! Stolen from a ghast. It didn't notice.";
	}
	States
	{
	Ready:
		MFCH A 1 A_WeaponReady;
		Loop;
	Deselect:
		MFCH A 1 A_Lower;
		Loop;
	Select:
		MFCH A 1 A_Raise;
		Loop;
	Fire:
		MFCH B 3 Bright { A_FireProjectile("MCFireCharge", frandom(-1, 1), true); A_StartSound("mc/blazeshot", CHAN_WEAPON); }
		MFCH A 2 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WFCH A -1;
		Stop;
	}
}

class MCCatFish : BFG9000 replaces BFG9000
{
	Default
	{
		Weapon.SlotNumber 7;
		Tag "The Cat's Fish";
		Inventory.PickupMessage "The Cat's fish! It will NOT be happy.";
	}
	States
	{
	Ready:
		MCOD A 1 A_WeaponReady;
		Loop;
	Deselect:
		MCOD A 1 A_Lower;
		Loop;
	Select:
		MCOD A 1 A_Raise;
		Loop;
	Fire:
		MCOD A 10 A_StartSound("cat/hiss", CHAN_WEAPON);
		MCOD B 10;
		MCOD B 2
		{
			A_FireProjectile("MCFishBomb", 0, true);
			A_StartSound("mc/tntshot", CHAN_WEAPON);
			if (random(0, 1)) MCStory.Cat("MY FISH! You threw MY FISH!");
			else MCStory.Cat("That was a premium cod. Unforgivable.");
		}
		TNT1 A 14;
		MCOD A 10 A_ReFire;
		Goto Ready;
	Flash:
		Stop;
	Spawn:
		WCOD A -1;
		Stop;
	}
}

// ---------------------------------------------------------------- player projectiles
class MCHitPuff : Actor
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		+NOBLOCKMAP
		+FORCEXYBILLBOARD
		Scale 0.25;
		AttackSound "mc/swordhit";
	}
	States
	{
	Spawn:
		MCPF AB 3 Bright;
		Stop;
	}
}

class MCPlayerArrow : MCArrow
{
	// The Cat is too smart to stand in the way: player shots fly through it.
	override bool CanCollideWith(Actor other, bool passive)
	{
		return !(other is "SuperCat");
	}

	Default
	{
		Speed 45;
		Gravity 0.06;
		DamageFunction (random(10, 18));
		SeeSound "";
		+BLOODLESSIMPACT
	}
	override void Tick()
	{
		Super.Tick();
		// A thin white trail so you can follow the shot.
		if (!bDestroyed && bMissile && GetAge() > 1)
		{
			FSpawnParticleParams p;
			p.color1 = 0xffffff;
			p.style = STYLE_Add;
			p.flags = SPF_FULLBRIGHT;
			p.lifetime = 8;
			p.size = 2.5;
			p.startalpha = 0.6;
			p.fadestep = -1;
			p.pos = pos;
			level.SpawnParticle(p);
		}
	}
}

class MCPlayerBolt : MCPlayerArrow
{
	Default { Speed 50; DamageFunction (random(14, 24)); }
}

class MCPlayerTNT : MCTNTShot
{
	Default { Speed 26; Gravity 0.35; Damage 20; }
}

class MCFireCharge : Actor
{
	override bool CanCollideWith(Actor other, bool passive) { return !(other is "SuperCat"); }
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Speed 30;
		DamageFunction (random(14, 30));
		Scale 0.3;
		+FORCEXYBILLBOARD
		+BRIGHT
		DeathSound "mc/blockbreak";
	}
	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && bMissile) MCFX.BlockBurst(pos, "MCLAVA1", 1, 0.6, 2.5);
	}
	States
	{
	Spawn:
		MCFB AB 2 Bright;
		Loop;
	Death:
		MCFL A 3 Bright { MCFX.BlockBurst(pos, "MCLAVA1", 8, 3, 4); A_SetScale(0.4); }
		MCFL B 3 Bright;
		Stop;
	}
}

// The BFG's place: the Cat's fish. It flies, it flops, it blows up everything around it in a rain of fish shards.
class MCFishBomb : Actor
{
	override bool CanCollideWith(Actor other, bool passive) { return !(other is "SuperCat"); }
	Default
	{
		Projectile;
		Radius 12;
		Height 12;
		Speed 22;
		Damage 30;
		Scale 2.2;
		+FORCEXYBILLBOARD
		+ROLLSPRITE
		DeathSound "mc/boom";
	}
	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && bMissile)
		{
			roll += 25;
			if (level.maptime % 2 == 0) MCFX.BlockBurst(pos, "MCWATER1", 2, 1.5, 4);
		}
	}
	States
	{
	Spawn:
		WCOD A 1;
		Loop;
	Death:
		TNT1 A 0
		{
			A_StartSound("mc/boom", CHAN_AUTO, 0, 1, 0.3);
			A_Explode(320, 320, 0, true, 120);
			MCFX.Explosion(self, 110, "MCWATER1");
			MCFX.BlockBurst(pos + (0, 0, 16), "MCWATER1", 30, 9, 8);
			A_QuakeEx(6, 6, 4, 26, 0, 1400, "", QF_SCALEDOWN);
		}
		TNT1 A 1;
		Stop;
	}
}
