// SuperIntelligent Cat - the Minecraft mobs that replace Doom's monsters.
// Shared (MCMob): the red hurt flash, cube shards knocked off on every hit, and the Minecraft death:
// the mob falls over, then puffs into smoke and spills XP orbs.

class MCMob : Actor abstract
{
	int hurtTics, xpValue;
	TranslationID baseTrans;
	String shardTex, shardTex2;
	Property XP: xpValue;
	Property Shards: shardTex, shardTex2;

	Default
	{
		Monster;
		+NOBLOOD
		+FLOORCLIP
		+DONTHARMSPECIES
		MCMob.XP 5;
		MCMob.Shards "MCDIRT", "MCSTONE";
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		baseTrans = translation;
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int r = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (bDestroyed) return r;
		hurtTics = 7;
		A_SetTranslation("MCHurt");
		Vector3 at = pos + (0, 0, height * 0.6);
		if (inflictor && inflictor != self && !(inflictor is "MCAnvil")) at = (pos.xy + (inflictor.pos.xy - pos.xy).Unit() * radius, at.z);
		MCFX.BlockBurst(at, random(0, 1) ? shardTex : shardTex2, 5, 3.2, 4);
		return r;
	}

	override void Tick()
	{
		Super.Tick();
		if (hurtTics > 0 && --hurtTics == 0 && !bDestroyed) translation = baseTrans;
	}

	// The Minecraft death: smoke, a pop, XP.
	void A_MobPoof()
	{
		MCFX.Poof(pos + (0, 0, height * 0.4), max(radius, 12) * scale.x, 12);
		A_StartSound("mc/pop", CHAN_AUTO);
		MCDrops.Spill(self, xpValue);
	}
}

// ---------------------------------------------------------------- creeper
class MCCreeper : MCMob
{
	Actor scaredOf;
	int scaredUntil, fuse, boomDamage;
	bool savable; // the Cat may hiss this fuse away (2 in 3)
	double boomRadius;
	Property Boom: boomDamage, boomRadius;

	Default
	{
		Health 80;
		Radius 14;
		Height 54;
		Speed 9;
		Mass 100;
		PainChance 150;
		MeleeRange 70;
		MCCreeper.Boom 110, 176;
		MCMob.Shards "MCLEAVES", "MCGRASS";
		PainSound "creeper/hurt";
		DeathSound "creeper/hurt";
		Obituary "%o was blown up by a creeper.";
		Tag "Creeper";
		+NOINFIGHTING
	}

	void Scare(Actor cat)
	{
		if (!Scared() && health > 0)
		{
			// Startled: a hop and a puff of leaves, then it runs.
			vel.z += 6;
			MCFX.BlockBurst(pos + (0, 0, height), "MCLEAVES", 6, 2.5, 4);
			A_StartSound("creeper/hurt", CHAN_VOICE);
			let s = MCStory.Get();
			if (s && level.maptime - s.creeperTalk > 35 * 7)
			{
				s.creeperTalk = level.maptime;
				static const String lines[] = { "NOPE.", "nope nope nope nope", "A CAT?! I'm out.", "Not the cat! Anything but the cat!" };
				MCStory.Say("Creeper", lines[random(0, lines.Size() - 1)]);
			}
		}
		scaredOf = cat;
		scaredUntil = level.maptime + 160;
		if (fuse) Defuse();
		if (health > 0 && !InStateSequence(CurState, FindState("Flee"))) SetStateLabel("Flee");
	}

	bool Scared() { return scaredOf && level.maptime < scaredUntil; }

	void A_RunAway()
	{
		if (!Scared()) { SetStateLabel("See"); return; }
		// Away from the Cat and away from the player: you see its back as it runs.
		Vector2 away = (pos.xy - scaredOf.pos.xy).Unit();
		let pl = players[consoleplayer].mo;
		if (pl) away += (pos.xy - pl.pos.xy).Unit();
		double want = VectorAngle(away.x, away.y) + frandom(-15, 15);
		angle = want;
		Vector2 step = AngleToVector(angle, Speed * 1.7);
		if (!TryMove(pos.xy + step, true))
		{
			angle = want + (random(0, 1) ? 70 : -70);
			TryMove(pos.xy + AngleToVector(angle, Speed * 1.5), true);
		}
		if (random(0, 8) == 0) A_StartSound("creeper/hurt", CHAN_VOICE, 0, 0.6);
	}

	void A_CreeperChase()
	{
		if (Scared()) { SetStateLabel("Flee"); return; }
		A_Chase();
	}

	void A_StartFuse()
	{
		fuse = 0;
		savable = random(0, 2) > 0;
		A_StartSound("mc/fuse", CHAN_BODY);
	}

	void A_FuseTick()
	{
		fuse += 3;
		A_FaceTarget();
		A_SetScale(1 + fuse * 0.0065);
		if (Scared() || !target || target.health <= 0 || Distance3D(target) > MeleeRange + 110)
		{
			Defuse();
			if (Scared()) SetStateLabel("Flee");
			else SetStateLabel("See");
			return;
		}
		if (fuse >= 45) A_Die('Fuse');
	}

	void Defuse()
	{
		fuse = 0;
		A_SetScale(1);
		A_StopSound(CHAN_BODY);
	}

	void A_CreeperBoom()
	{
		A_StopSound(CHAN_BODY);
		A_StartSound("mc/boom", CHAN_AUTO, 0, 1, 0.45);
		A_Explode(boomDamage, int(boomRadius), XF_HURTSOURCE, true, int(boomRadius * 0.3));
		MCFX.Explosion(self, boomRadius * 0.4 * scale.x);
		A_QuakeEx(4, 4, 3, 18, 0, 900, "", QF_SCALEDOWN);
		MCDrops.Spill(self, xpValue);
		A_NoBlocking();
	}

	States
	{
	Spawn:
		CREP A 10 A_Look;
		Loop;
	See:
		CREP AABB 4 A_CreeperChase;
		Loop;
	Flee:
		CREP AABB 3 A_RunAway;
		Loop;
	Melee:
		CREP D 0 A_StartFuse;
	Fuse:
		CREP D 3 A_FuseTick;
		CREP E 3 Bright A_FuseTick;
		Loop;
	Pain:
		CREP C 6 A_Pain;
		Goto See;
	Death:
		CREP E 3 Bright A_SetScale(scale.x * 1.15);
		CREP D 2 Bright A_SetScale(scale.x * 1.1);
		CREP E 2 Bright A_CreeperBoom;
		Stop;
	}
}

// The Cyberdemon's place: a charged creeper titan that fires TNT.
class MCCreeperTitan : MCCreeper
{
	Default
	{
		Health 4000;
		Radius 40;
		Height 170;
		Scale 2.9;
		Speed 12;
		Mass 1000;
		PainChance 20;
		MeleeRange 120;
		MCCreeper.Boom 220, 360;
		MCMob.XP 60;
		Translation "MCCharged";
		Tag "Charged Creeper Titan";
		+BOSS
		+NORADIUSDMG
	}
	States
	{
	Missile:
		CREP D 10 Bright A_FaceTarget;
		CREP D 6 Bright A_SpawnProjectile("MCTNTShot", 120);
		CREP A 10 A_FaceTarget;
		CREP D 6 Bright A_SpawnProjectile("MCTNTShot", 120);
		Goto See;
	}
}

// ---------------------------------------------------------------- zombie
class MCZombie : MCMob
{
	Default
	{
		Health 60;
		Radius 16;
		Height 56;
		Speed 8;
		Mass 100;
		PainChance 200;
		MCMob.Shards "MCLEAVES", "MCLAPIS";
		SeeSound "zombie/idle";
		ActiveSound "zombie/idle";
		PainSound "zombie/hurt";
		DeathSound "zombie/die";
		Obituary "%o was eaten by a zombie.";
		Tag "Zombie";
	}
	States
	{
	Spawn:
		MCZB A 10 A_Look;
		Loop;
	See:
		MCZB AABB 5 A_Chase;
		Loop;
	Melee:
		MCZB C 8 A_FaceTarget;
		MCZB C 6 A_CustomMeleeAttack(random(6, 14), "mc/swordhit", "", 'Melee', true);
		MCZB A 6;
		Goto See;
	Pain:
		MCZB D 6 A_Pain;
		Goto See;
	Death:
		MCZB D 4 A_Scream;
		MCZB E 22 A_NoBlocking;
		MCZB E 0 A_MobPoof;
		Stop;
	}
}

class MCHusk : MCZombie
{
	Default { Health 60; Translation "MCHusk"; MCMob.Shards "MCSAND", "MCSANDST"; Tag "Husk"; }
}

// The Mancubus's place: a giant zombie, slow and heavy.
class MCGiantZombie : MCZombie
{
	Default
	{
		Health 600;
		Radius 40;
		Height 112;
		Scale 2.0;
		Speed 7;
		Mass 1000;
		PainChance 60;
		MCMob.XP 30;
		Tag "Giant Zombie";
	}
	States
	{
	Melee:
		MCZB C 12 A_FaceTarget;
		MCZB C 8 A_CustomMeleeAttack(random(20, 40), "mc/anvil", "", 'Melee', true);
		MCZB A 8;
		Goto See;
	}
}

// ---------------------------------------------------------------- skeleton
class MCSkeleton : MCMob
{
	Default
	{
		Health 50;
		Radius 16;
		Height 58;
		Speed 8;
		Mass 100;
		PainChance 170;
		MCMob.Shards "MCQUARTZ", "MCSNOW";
		SeeSound "skeleton/idle";
		ActiveSound "skeleton/idle";
		PainSound "skeleton/hurt";
		DeathSound "skeleton/die";
		Obituary "%o was shot by a skeleton.";
		Tag "Skeleton";
	}
	States
	{
	Spawn:
		MCSK A 10 A_Look;
		Loop;
	See:
		MCSK AABB 4 A_Chase;
		Loop;
	Missile:
		MCSK C 12 A_FaceTarget;
		MCSK C 0 A_StartSound("mc/bowpull", CHAN_WEAPON);
		MCSK C 6 A_FaceTarget;
		MCSK C 8 A_SpawnProjectile("MCArrow", 36);
		MCSK A 6;
		Goto See;
	Pain:
		MCSK D 6 A_Pain;
		Goto See;
	Death:
		MCSK D 4 A_Scream;
		MCSK E 22 A_NoBlocking;
		MCSK E 0 A_MobPoof;
		Stop;
	}
}

class MCStray : MCSkeleton
{
	Default { Health 70; Translation "MCStray"; Tag "Stray"; }
	States
	{
	Missile:
		MCSK C 10 A_FaceTarget;
		MCSK C 4 A_SpawnProjectile("MCArrow", 36, 0, frandom(-4, 4));
		MCSK C 4 A_SpawnProjectile("MCArrow", 36, 0, frandom(-4, 4));
		MCSK C 4 A_SpawnProjectile("MCArrow", 36, 0, frandom(-4, 4));
		MCSK A 8;
		Goto See;
	}
}

// The Revenant's place: a wither skeleton with flaming arrows.
class MCWitherSkeleton : MCSkeleton
{
	Default
	{
		Health 300;
		Radius 18;
		Height 70;
		Scale 1.2;
		Speed 10;
		PainChance 100;
		MCMob.XP 15;
		MCMob.Shards "MCOBSID", "MCCOALOR";
		Translation "MCWither";
		Tag "Wither Skeleton";
	}
	States
	{
	Missile:
		MCSK C 10 A_FaceTarget;
		MCSK C 6 A_SpawnProjectile("MCFireArrow", 42);
		MCSK A 8;
		Goto See;
	Melee:
		MCSK C 6 A_FaceTarget;
		MCSK C 6 A_CustomMeleeAttack(random(10, 25), "mc/swordhit", "", 'Melee', true);
		Goto See;
	}
}

class MCArrow : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		Gravity 0.12;
		Radius 4;
		Height 6;
		Speed 28;
		DamageFunction (random(6, 12));
		SeeSound "mc/bowshot";
		DeathSound "mc/arrowhit";
		+FORCEXYBILLBOARD
		Scale 0.9;
	}
	States
	{
	Spawn:
		MCAR A 1;
		Loop;
	Death:
		MCAR A 70;
		MCAR A 10 A_FadeOut(0.2);
		Wait;
	XDeath:
		TNT1 A 1 A_StartSound("mc/arrowhit", CHAN_AUTO);
		Stop;
	}
}

class MCFireArrow : MCArrow
{
	Default { Speed 22; DamageFunction (random(12, 22)); }
	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && vel.Length() > 1) MCFX.BlockBurst(pos, "MCLAVA1", 1, 0.5, 3);
	}
}

// ---------------------------------------------------------------- spider
class MCSpider : MCMob
{
	Default
	{
		Health 140;
		Radius 30;
		Height 36;
		Speed 12;
		Mass 300;
		PainChance 180;
		MaxTargetRange 420;
		MinMissileChance 120;
		MCMob.Shards "MCOBSID", "MCREDORE";
		SeeSound "spider/idle";
		ActiveSound "spider/idle";
		PainSound "spider/idle";
		DeathSound "spider/die";
		Obituary "%o got bitten by a spider.";
		Tag "Spider";
	}

	void A_SpiderLeap()
	{
		if (!target) return;
		A_FaceTarget();
		double d = Distance2D(target);
		Vel3DFromAngle(clamp(d / 22, 8, 18), angle, -30);
		A_StartSound("spider/idle", CHAN_VOICE);
	}

	States
	{
	Spawn:
		MCSP A 10 A_Look;
		Loop;
	See:
		MCSP AABB 3 A_Chase;
		Loop;
	Missile:
		MCSP C 8 A_FaceTarget;
		MCSP C 16 A_SpiderLeap;
		Goto See;
	Melee:
		MCSP C 6 A_FaceTarget;
		MCSP C 6 A_CustomMeleeAttack(random(8, 18), "mc/swordhit", "", 'Melee', true);
		MCSP A 4;
		Goto See;
	Pain:
		MCSP D 6 A_Pain;
		Goto See;
	Death:
		MCSP D 4 A_Scream;
		MCSP E 24 A_NoBlocking;
		MCSP E 0 A_MobPoof;
		Stop;
	}
}

class MCCaveSpider : MCSpider
{
	Default { Health 90; Radius 20; Height 26; Scale 0.7; Speed 14; Translation "MCCave"; MCMob.Shards "MCLAPIS", "MCOBSID"; Tag "Cave Spider"; }
}

class MCSpiderJockey : MCSpider
{
	Default { Health 500; Radius 42; Height 52; Scale 1.45; Speed 11; PainChance 80; MCMob.XP 20; Tag "Giant Spider"; }
	States
	{
	Missile:
		MCSP C 10 A_FaceTarget;
		MCSP C 4 A_SpawnProjectile("MCArrow", 30, 0, -8);
		MCSP C 4 A_SpawnProjectile("MCArrow", 30, 0, 0);
		MCSP C 4 A_SpawnProjectile("MCArrow", 30, 0, 8);
		MCSP A 6;
		Goto See;
	}
}

class MCSpiderQueen : MCSpider
{
	Default
	{
		Health 3000;
		Radius 80;
		Height 100;
		Scale 2.8;
		Speed 12;
		Mass 1000;
		PainChance 40;
		MCMob.XP 60;
		Translation "MCWither";
		Tag "Spider Queen";
		+BOSS
		+NORADIUSDMG
	}
	States
	{
	Missile:
		MCSP C 8 A_FaceTarget;
		MCSP C 3 A_SpawnProjectile("MCArrow", 60, 0, frandom(-10, 10));
		MCSP C 3 A_SpawnProjectile("MCArrow", 60, 0, frandom(-10, 10));
		MCSP C 3 A_SpawnProjectile("MCArrow", 60, 0, frandom(-10, 10));
		MCSP C 3 A_SpawnProjectile("MCArrow", 60, 0, frandom(-10, 10));
		MCSP A 8;
		Goto See;
	}
}

// ---------------------------------------------------------------- ghast
class MCGhast : MCMob
{
	Default
	{
		Health 320;
		Radius 34;
		Height 80;
		Speed 7;
		Mass 400;
		PainChance 128;
		MCMob.XP 12;
		MCMob.Shards "MCWOOL", "MCSNOW";
		+FLOAT
		+NOGRAVITY
		SeeSound "ghast/cry";
		ActiveSound "ghast/cry";
		PainSound "ghast/cry";
		DeathSound "ghast/die";
		Obituary "%o was fireballed by a ghast.";
		Tag "Ghast";
	}
	States
	{
	Spawn:
		MCGH A 10 A_Look;
		Loop;
	See:
		MCGH AABB 4 A_Chase;
		Loop;
	Missile:
		MCGH A 8 A_FaceTarget;
		MCGH C 10 Bright A_StartSound("ghast/fire", CHAN_WEAPON);
		MCGH C 8 Bright A_SpawnProjectile("MCGhastFireball", 36);
		MCGH A 8;
		Goto See;
	Pain:
		MCGH D 8 A_Pain;
		Goto See;
	Death:
		MCGH D 6 A_Scream;
		MCGH E 26 A_NoBlocking;
		MCGH E 0 A_MobPoof;
		Stop;
	}
}

class MCGhastling : MCGhast
{
	Default
	{
		Health 60;
		Radius 14;
		Height 32;
		Scale 0.4;
		Speed 8;
		Mass 50;
		PainChance 256;
		Damage 3;
		MCMob.XP 3;
		Tag "Ghastling";
		-COUNTKILL
	}
	States
	{
	Missile:
		MCGH C 10 Bright A_FaceTarget;
		MCGH C 4 Bright A_SkullAttack;
		MCGH CC 4 Bright;
		Goto Missile + 2;
	}
}

class MCGhastMother : MCGhast
{
	Default { Health 400; Radius 40; Height 96; Scale 1.25; Speed 6; MCMob.XP 20; Translation "MCPurple"; Tag "Ghast Mother"; }
	States
	{
	Missile:
		MCGH C 10 Bright A_FaceTarget;
		MCGH C 8 Bright A_PainAttack("MCGhastling");
		MCGH A 8;
		Goto See;
	Death:
		MCGH D 6 A_Scream;
		MCGH E 8 A_PainDie("MCGhastling");
		MCGH E 18 A_NoBlocking;
		MCGH E 0 A_MobPoof;
		Stop;
	}
}

// A ghast fireball: shoot or hit it and it flies back the other way.
class MCGhastFireball : Actor
{
	bool returned;
	Default
	{
		Projectile;
		Radius 10;
		Height 16;
		Speed 14;
		Health 1000;
		Damage 0;
		+SHOOTABLE
		+NOBLOOD
		+NODAMAGE
		+DONTTHRUST
		+FORCEXYBILLBOARD
		+BRIGHT
		Scale 0.6;
		DeathSound "mc/boom";
	}
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (!returned && source && source.player)
		{
			returned = true;
			Actor home = target;
			target = source; // now it is the player's fireball
			if (home) vel = (home.pos + (0, 0, home.height * 0.5) - pos).Unit() * Speed * 1.6;
			else vel = -vel * 1.6;
			A_StartSound("mc/swordhit", CHAN_AUTO);
			MCFX.BlockBurst(pos, "MCLAVA1", 10, 4, 4);
			MCStory.Advance("Return to Sender", "Send a ghast's fireball back at it");
			MCStory.Cat("Ha! Return to sender. I taught you that. Telepathically.");
		}
		return 0;
	}
	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && bMissile && level.maptime % 2 == 0) MCFX.BlockBurst(pos, "MCLAVA1", 1, 0.8, 3);
	}
	States
	{
	Spawn:
		MCFB AB 3 Bright;
		Loop;
	Death:
		MCFB A 1 Bright { A_Explode(45, 110); MCFX.Explosion(self, 30); bShootable = false; }
		Stop;
	}
}

// ---------------------------------------------------------------- enderman
class MCEnderman : MCMob
{
	int blinkAt;
	Default
	{
		Health 450;
		Radius 18;
		Height 92;
		Speed 11;
		Mass 500;
		PainChance 110;
		MCMob.XP 15;
		MCMob.Shards "MCOBSID", "MCPURPUR";
		SeeSound "ender/tele";
		ActiveSound "ender/hurt";
		PainSound "ender/hurt";
		DeathSound "ender/die";
		Obituary "%o looked an enderman in the eyes.";
		Tag "Enderman";
	}

	// Hurt endermen teleport around their target, leaving purple shards.
	void A_Blink()
	{
		if (!target || level.maptime - blinkAt < 35 || random(0, 2) == 0) return;
		for (int i = 0; i < 10; i++)
		{
			Vector2 xy = target.Vec2Angle(frandom(140, 300), frandom(0, 360));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - pos.z) > 64) continue;
			Vector3 old = pos;
			SetOrigin((xy, z), false);
			if (TestMobjLocation() && CheckSight(target))
			{
				MCFX.BlockBurst(old + (0, 0, 46), "MCPURPUR", 14, 3, 4);
				MCFX.BlockBurst(pos + (0, 0, 46), "MCPURPUR", 14, 3, 4);
				A_StartSound("ender/tele", CHAN_BODY);
				angle = AngleTo(target);
				blinkAt = level.maptime;
				ClearInterpolation();
				return;
			}
			SetOrigin(old, false);
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && health > 0 && level.maptime % 6 == 0) MCFX.BlockBurst(pos + (frandom(-12, 12), frandom(-12, 12), frandom(10, 80)), "MCPURPUR", 1, 0.4, 2.5);
	}

	States
	{
	Spawn:
		MCEN A 10 A_Look;
		Loop;
	See:
		MCEN AABB 4 A_Chase;
		Loop;
	Melee:
		MCEN C 8 A_FaceTarget;
		MCEN C 6 A_CustomMeleeAttack(random(14, 30), "mc/swordhit", "", 'Melee', true);
		MCEN A 6;
		Goto See;
	Pain:
		MCEN D 6 A_Pain;
		MCEN D 2 A_Blink;
		Goto See;
	Death:
		MCEN D 4 A_Scream;
		MCEN E 20 A_NoBlocking;
		MCEN E 0 { MCFX.BlockBurst(pos + (0, 0, 46), "MCPURPUR", 24, 4, 5); A_MobPoof(); }
		Stop;
	}
}

class MCEnderLord : MCEnderman
{
	Default { Health 900; Radius 22; Height 106; Scale 1.15; MCMob.XP 25; Translation "MCPurple"; Tag "Ender Lord"; }
}

// The Arch-vile's place: an ender mage that blinks a lot and throws ender fire.
class MCEnderMage : MCEnderman
{
	Default { Health 700; MCMob.XP 25; Translation "MCPurple"; Tag "Ender Mage"; MaxTargetRange 900; }
	States
	{
	Missile:
		MCEN C 12 Bright A_FaceTarget;
		MCEN C 8 Bright A_SpawnProjectile("MCGhastFireball", 70);
		MCEN A 4 A_Blink;
		Goto See;
	}
}

// ---------------------------------------------------------------- TNT
// Doom's explosive barrels become TNT: shoot it, it flashes and hisses, then it blows (and sets off its neighbours).
class MCTNTBlock : Actor
{
	Default
	{
		Health 20;
		Radius 14;
		Height 30;
		Mass 1000;
		+SOLID
		+SHOOTABLE
		+NOBLOOD
		+DONTGIB
		+NOICEDEATH
		+OLDRADIUSDMG
		+ACTIVATEMCROSS
		DeathSound "mc/boom";
		Obituary "%o played with TNT.";
		Tag "TNT";
	}
	States
	{
	Spawn:
		BAR1 A -1;
		Stop;
	Death:
		BAR1 B 4 Bright A_StartSound("mc/fuse", CHAN_BODY);
		BAR1 A 4;
		BAR1 B 4 Bright A_SetScale(1.08);
		BAR1 A 3;
		BAR1 B 3 Bright A_SetScale(1.16);
		BAR1 B 2 Bright
		{
			A_StopSound(CHAN_BODY);
			A_StartSound("mc/boom", CHAN_AUTO, 0, 1, 0.45);
			A_NoBlocking();
			A_Explode(128, 160, XF_HURTSOURCE, true, 40);
			MCFX.Explosion(self, 50, "MCTNT");
			A_QuakeEx(4, 4, 3, 18, 0, 900, "", QF_SCALEDOWN);
		}
		TNT1 A 1;
		Stop;
	}
}

// Thrown TNT (the TNT cannon and the creeper titan): sparks on its fuse, explodes on impact.
class MCTNTShot : Actor
{
	override bool CanCollideWith(Actor other, bool passive) { return !(other is "SuperCat"); }
	Default
	{
		Projectile;
		Radius 8;
		Height 10;
		Speed 22;
		Damage 10;
		-NOGRAVITY
		Gravity 0.25;
		SeeSound "mc/tntshot";
		+FORCEXYBILLBOARD
		Scale 0.55;
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || !bMissile) return;
		FSpawnParticleParams p;
		p.color1 = level.maptime % 2 ? 0xffee88 : 0xff8822;
		p.style = STYLE_Add;
		p.flags = SPF_FULLBRIGHT;
		p.lifetime = 14;
		p.size = 4;
		p.sizestep = -0.2;
		p.startalpha = 1;
		p.fadestep = -1;
		p.pos = pos + (0, 0, 8);
		p.vel = (frandom(-1, 1), frandom(-1, 1), frandom(0.5, 1.5));
		level.SpawnParticle(p);
		if (level.maptime % 3 == 0) Actor.Spawn("MCPuff", pos - vel * 0.5);
	}
	States
	{
	Spawn:
		BAR1 A 2;
		BAR1 B 2 Bright;
		Loop;
	Death:
		TNT1 A 1
		{
			A_StartSound("mc/boom", CHAN_AUTO, 0, 1, 0.45);
			A_Explode(128, 150, XF_HURTSOURCE, true, 40);
			MCFX.Explosion(self, 46, "MCTNT");
			A_QuakeEx(3, 3, 2, 14, 0, 700, "", QF_SCALEDOWN);
		}
		Stop;
	}
}
