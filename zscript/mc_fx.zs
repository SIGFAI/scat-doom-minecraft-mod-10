// SuperIntelligent Cat - effects: block shards, smoke puffs, the Minecraft explosion, XP orbs.

class MCFX play
{
	// Square shards cut from a block texture, flying out and falling (Minecraft's break particles).
	static void BlockBurst(Vector3 pos, String tex, int count, double speed, double size = 5)
	{
		TextureID t = TexMan.CheckForTexture(tex, TexMan.Type_Any);
		if (!t.IsValid()) t = TexMan.CheckForTexture("MCDIRT", TexMan.Type_Any);
		FSpawnParticleParams p;
		p.texture = t;
		p.style = STYLE_Normal;
		p.flags = SPF_ROLL;
		p.startalpha = 1;
		p.fadestep = 0;
		p.sizestep = -0.05;
		for (int i = 0; i < count; i++)
		{
			p.color1 = 0xffffff;
			p.lifetime = random(25, 45);
			p.size = size * frandom(0.6, 1.4);
			p.pos = pos + (frandom(-8, 8), frandom(-8, 8), frandom(-8, 8));
			p.vel = (frandom(-speed, speed), frandom(-speed, speed), frandom(speed * 0.4, speed * 1.4));
			p.accel = (0, 0, -0.45);
			p.startroll = frandom(0, 360);
			p.rollvel = frandom(-12, 12);
			level.SpawnParticle(p);
		}
	}

	// White-grey smoke puffs (a creature popping in or out of the world).
	static void Poof(Vector3 pos, double r, int count)
	{
		for (int i = 0; i < count; i++)
		{
			let s = Actor.Spawn("MCPuff", pos + (frandom(-r, r), frandom(-r, r), frandom(-r * 0.8, r * 0.8)));
			if (s)
			{
				s.vel = (frandom(-1.2, 1.2), frandom(-1.2, 1.2), frandom(0.3, 1.6));
				s.scale *= frandom(0.6, 1.1);
			}
		}
	}

	// A Minecraft explosion: a ball of big puffs, a flash, block shards from the floor, a crater of debris.
	static void Explosion(Actor src, double r, String floorTex = "")
	{
		Vector3 c = src.pos + (0, 0, 8);
		let f = Actor.Spawn("MCBoomFlash", c + (0, 0, 16));
		for (int i = 0; i < 16; i++)
		{
			let s = Actor.Spawn("MCBigPuff", c + (frandom(-r, r) * 0.5, frandom(-r, r) * 0.5, frandom(0, r * 0.6)));
			if (s)
			{
				s.vel = (frandom(-3, 3), frandom(-3, 3), frandom(0.5, 3.5));
				s.scale *= frandom(0.8, 1.6);
			}
		}
		if (floorTex == "") floorTex = TexMan.GetName(src.floorpic);
		if (floorTex.Left(2) != "MC") floorTex = "MCDIRT";
		BlockBurst(c, floorTex, 26, 7, 7);
		BlockBurst(c, "MCSTONE", 12, 6, 6);
		BlockBurst(c, "MCTNT", 6, 5, 5);
	}
}

class MCPuff : Actor
{
	Default
	{
		+NOINTERACTION
		+FORCEXYBILLBOARD
		RenderStyle "Translucent";
		Alpha 0.95;
		Scale 0.45;
	}
	// Smoke never fills the screen: close to the camera it thins out fast.
	override void Tick()
	{
		Super.Tick();
		let c = players[consoleplayer].camera;
		if (!bDestroyed && c && Distance3D(c) < 110) A_FadeOut(0.15);
	}
	States
	{
	Spawn:
		MCPF AB 4 Bright;
		MCPF C 4 Bright A_FadeOut(0.2);
		MCPF D 4 Bright A_FadeOut(0.3);
		Stop;
	}
}

// Explosion smoke: big and white at first, then grey and gone (never a white wall in front of the camera).
class MCBigPuff : MCPuff
{
	Default { Scale 0.8; }
	States
	{
	Spawn:
		MCPF A 3 Bright;
		MCPF B 4 Bright A_ScaleVelocity(0.85);
		MCPF C 4 Bright { A_ScaleVelocity(0.85); A_FadeOut(0.2); }
		MCPF CD 4 Bright A_FadeOut(0.2);
		MCPF D 4 Bright A_FadeOut(0.3);
		Stop;
	}
}

class MCBoomFlash : Actor
{
	// A flash right next to the camera would white out the screen: it stays faint up close.
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let c = players[consoleplayer].camera;
		if (c) { double d = Distance3D(c); if (d < 260) { alpha *= max(0.25, d / 260); scale *= max(0.5, d / 260); } }
	}

	Default
	{
		+NOINTERACTION
		+FORCEXYBILLBOARD
		RenderStyle "Add";
		Scale 2.6;
		Alpha 0.95;
	}
	States
	{
	Spawn:
		MCFL A 2 Bright A_AttachLight("boom", DynamicLight.PointLight, 0xffe0a0, 260, 0);
		MCFL A 2 Bright A_SetScale(3.2);
		MCFL B 3 Bright A_FadeOut(0.25);
		MCFL B 3 Bright A_FadeOut(0.3);
		Stop;
	}
}

// An experience orb: bobs, then homes in on the player, ding.
class MCXPOrb : Actor
{
	int worth;
	Default
	{
		Radius 4;
		Height 8;
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		+FORCEXYBILLBOARD
		Gravity 0.5;
		Scale 0.6;
		RenderStyle "Normal";
	}
	override void BeginPlay()
	{
		Super.BeginPlay();
		worth = 1;
		vel = (frandom(-3, 3), frandom(-3, 3), frandom(3, 6));
	}
	override void Tick()
	{
		Super.Tick();
		if (GetAge() < 18) return;
		let p = players[consoleplayer].mo;
		if (!p) return;
		Vector3 to = p.pos + (0, 0, 24) - pos;
		double d = to.Length();
		if (d < 22)
		{
			MCPlayerXP.Add(p, worth);
			p.A_StartSound("mc/xp", CHAN_AUTO, 0, 0.7, ATTN_NONE, frandom(0.8, 1.3));
			Destroy();
			return;
		}
		if (d < 640)
		{
			bNoGravity = true;
			double spd = clamp(900. / max(d, 1), 4, 18);
			vel = to / d * spd;
		}
		else bNoGravity = false;
	}
	States
	{
	Spawn:
		MCXP AB 4 Bright;
		Loop;
	}
}

// Death drops: XP orbs for every mob, shared by WorldThingDied.
class MCDrops play
{
	static void Spill(Actor m, int xp)
	{
		int n = clamp(xp / 2, 2, 12);
		for (int i = 0; i < n; i++)
		{
			let o = MCXPOrb(Actor.Spawn("MCXPOrb", m.pos + (0, 0, m.height * 0.5)));
			if (o) o.worth = max(1, xp / n);
		}
	}
}
