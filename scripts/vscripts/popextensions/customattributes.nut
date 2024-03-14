::CustomAttributes <- {

    SpawnHookTable = {}
    TakeDamageTable = {}
    TakeDamagePostTable = {}
    PlayerTeleportTable = {}
    DeathHookTable = {}

    Attrs = {
        "fires milk bolt": null
        "mod teleporter speed boost": null
        "mult teleporter recharge rate": null
        "set turn to ice": null
        "melee cleave attack": null
        "extra damage on hit": null
        "scoreboard minigame": null
        "last shot crits": null
        "can breathe under water": null
        "cannot swim": null
        "swimming mastery": null
        "mod minigun can holster while spinning": null
        "wet immunity": null
        "ability master sniper": null
        "keep disguise on attack": null
        "add give health to teammate on hit": null
        "mult dispenser rate": null
        "mvm sentry ammo": null
        "build small sentries": null
        "kill combo fire rate boost": null
        "disguise as dispenser on crouch": null
        "ubercharge transfer": null
        "ubercharge ammo": null
        "teleport instead of die": null
        "mod projectile heat seek power": null
        "mult dmg vs same class": null
        "uber on damage taken": null
        "mult crit when health is below percent": null
        "penetration damage penalty": null
        "firing forward pull": null
        "mod soldier buff range": null
        "mult rocketjump deploy time": null
        "mult nonrocketjump attackrate": null
        "aoe heal chance": null
        "crits on damage": null
        "stun on damage": null
        "aoe blast on damage": null
        "mult dmg with reduced health": null
        "mult airblast primary refire time": null
        "mod flamethrower spinup time": null
        "airblast functionality flags": null
        "reverse airblast": null
        "airblast dashes": null
        "mult sniper charge per sec with enemy under crosshair": null
        "sniper beep with enemy under crosshair": null
    }

    Events = {

        function Cleanup()
        {
            return
        }
        
		function OnScriptHook_OnTakeDamage(params) { foreach (_, func in CustomAttributes.TakeDamageTable) func(params); }
		function OnGameEvent_player_hurt(params) { foreach (_, func in CustomAttributes.TakeDamagePostTable) func(params) }
		// function OnGameEvent_player_spawn(params) { foreach (_, func in CustomAttributes.SpawnHookTable) func(params) }
		function OnGameEvent_player_death(params) { foreach (_, func in CustomAttributes.DeathHookTable) func(params) }
		function OnGameEvent_player_teleported(params) {  foreach (_, func in CustomAttributes.PlayerTeleportTable) func(params) }
		// function OnGameEvent_player_disconnect(params) { foreach (_, func in CustomAttributes.DisconnectTable) func(params) }
		// function OnGameEvent_mvm_begin_wave(params) { foreach (_, func in CustomAttributes.StartWaveTable) func(params) }

		function OnGameEvent_post_inventory_application(params) {

			local player = GetPlayerFromUserID(params.userid)
			player.ValidateScriptScope()
			local scope = player.GetScriptScope()	

            local items = {

                PlayerThinkTable = {}
                teleporterspeedboost = false
                // PlayerTeleportTable = {}
            }

            foreach (k,v in items) if (!(k in scope)) scope[k] <- v

			foreach (_, func in CustomAttributes.SpawnHookTable) func(params)

			scope.PlayerThinks <- function() { foreach (name, func in scope.PlayerThinkTable) func(); return -1 }

			AddThinkToEnt(player, "PlayerThinks")

			if (player.GetPlayerClass() > TF_CLASS_PYRO && !("BuiltObjectTable" in scope)) 
			{
				scope.BuiltObjectTable <- {}
			}
		}

		function OnGameEvent_recalculate_holidays(params) {

			if (GetRoundState() != GR_STATE_PREROUND) return

            foreach (player in PopExtUtil.HumanArray)
                PopExtMain.PlayerCleanup(player)
		}

		// function OnGameEvent_mvm_wave_complete(params) {

		// 	CustomAttributes.Cleanup()
		// }

		function OnGameEvent_mvm_mission_complete(params) {

			delete ::CustomAttributes
		}
	}
}
__CollectGameEventCallbacks(CustomAttributes.Events)

function CustomAttributes::FireMilkBolt(player, item, value = 5.0) {

    local wep = PopExtUtil.HasItemInLoadout(player, item)
    if (wep == null) return
    
    local scope = player.GetScriptScope()
    scope.milkboltfired <- false

    scope.PlayerThinkTable.FireMilkBolt <- function() {
        
        if (player.GetActiveWeapon() != wep) return

        if (PopExtUtil.InButton(player, IN_ATTACK2)) 
        {
            wep.PrimaryAttack()
            scope.milkboltfired = true

        } else if (PopExtUtil.InButton(player, IN_ATTACK)) 
            scope.milkboltfired = false
    }
    CustomAttributes.TakeDamagePostTable.FireMilkBolt <- function(params) {

        local victim = GetPlayerFromUserID(params.userid)
        local attacker = GetPlayerFromUserID(params.attacker)

        if (victim == null || attacker == null || attacker != player || !scope.milkboltfired) return
        
        victim.AddCondEx(TF_COND_MAD_MILK, value, attacker)
        scope.milkboltfired = false
        
    }
}
function CustomAttributes::TeleportInsteadOfDie(player, item, value) {
    CustomAttributes.TakeDamageTable.TeleportInsteadOfDie <- function(params) {

        if (RandomFloat(0, 1) > value.tofloat()) return

        local player = params.const_entity
        
        if (!player.IsPlayer() || player.GetHealth() > params.damage || player.IsInvulnerable() || PopExtUtil.IsPointInRespawnRoom(player.EyePosition())) return

        local health = player.GetHealth()
        params.early_out = true
        
        player.ForceRespawn()
        EntFireByHandle(player, "RunScriptCode","self.SetHealth(1)", -1, null, null)
    }
}

function CustomAttributes::DmgVsSameClass(player, item, value) {
    
    CustomAttributes.TakeDamageTable.DmgVsSameClass <- function(params) {
        local victim = params.const_entity
        local attacker = params.attacker

        if (!attacker.IsPlayer() || !victim.IsPlayer() || attacker.GetPlayerClass() != victim.GetPlayerClass()) return

        params.damage *= value
    }
}
function CustomAttributes::MeleeCleaveAttack(player, item, value = 64) {

    local scope = player.GetScriptScope()
    local wep = PopExtUtil.HasItemInLoadout(player, item)
    if (wep == null) return
    local nextattack = 0.0
    scope.cleaved <- false

    scope.PlayerThinkTable.MeleeCleaveAttack <- function() {

        if (nextattack == GetPropFloat(wep, "m_flNextPrimaryAttack") || GetPropFloat(wep, "m_fFireDuration") == 0.0) return

        scope.cleaved = false

        nextattack = GetPropFloat(wep, "m_flNextPrimaryAttack")
    }
    CustomAttributes.TakeDamageTable.MeleeCleaveAttack <- function(params) {
        
        if (scope.cleaved) return

        local wep = PopExtUtil.HasItemInLoadout(player, item)
        if (wep == null) return

        scope.cleaved = true
        // params.early_out = true
        
        local swingpos = player.EyePosition() + (player.EyeAngles().Forward() * 30) - Vector(0, 0, value)

        for (local p; p = FindByClassnameWithin(p, "player", swingpos, value);)
            if (p.GetTeam() != player.GetTeam() && p.GetTeam() != TEAM_SPECTATOR)
                p.TakeDamageCustom(params.inflictor, params.attacker, params.weapon, params.damage_force, params.damage_position, params.damage, params.damage_type, params.damage_custom)
            
    }
}

function CustomAttributes::TeleporterRechargeTime(player, item, value = 1.0) {

    local wep = PopExtUtil.HasItemInLoadout(player, item)
    if (wep == null) return
    
    local scope = player.GetScriptScope()
    scope.teleporterrechargetimemult <- value
    
    // CustomAttributes.PlayerTeleportTable.TeleporterRechargeTime <- function(params) {
    //     local teleportedplayer = GetPlayerFromUserID(params.userid)

    //     local teleporter = FindByClassnameNearest("obj_teleporter", teleportedplayer.GetOrigin(), 16)

    //     local chargetime = GetPropFloat(teleporter, "m_flCurrentRechargeDuration")
    // }

    scope.PlayerThinkTable.TeleporterRechargeTime <- function() {

        local mult = scope.teleporterrechargetimemult
        local teleporter = FindByClassnameNearest("obj_teleporter", player.GetOrigin(), 16)

        if (teleporter == null || teleporter.GetScriptThinkFunc() != "") return

        teleporter.ValidateScriptScope()
        local chargetime = GetPropFloat(teleporter, "m_flCurrentRechargeDuration")

        local teleportscope = teleporter.GetScriptScope()
        if (!("rechargetimestamp" in teleportscope)) teleportscope.rechargetimestamp <- 0.0
        if (!("rechargeset" in teleportscope)) teleportscope.rechargeset <- false
        
        teleportscope.TeleportMultThink <- function() {

            // printl(GetPropFloat(teleporter, "m_flCurrentRechargeDuration"))

            if (!teleportscope.rechargeset)
            {
                SetPropFloat(teleporter, "m_flCurrentRechargeDuration", chargetime * mult)
                SetPropFloat(teleporter, "m_flRechargeTime", Time() * mult)

                teleportscope.rechargeset = true
                teleportscope.rechargetimestamp = GetPropFloat(teleporter, "m_flRechargeTime") * mult
            }
            if (GetPropInt(teleporter, "m_iState") == 6 && GetPropFloat(teleporter, "m_flRechargeTime") >= teleportscope.rechargetimestamp)
            {
                teleportscope.rechargeset = false
            }

            printl(GetPropFloat(teleporter, "m_flRechargeTime") + " : " + teleportscope.rechargetimestamp)
            return -1
        }
        AddThinkToEnt(teleporter, "TeleportMultThink")
    }
}

function CustomAttributes::UberOnDamageTaken(player, item, value) { 
    
    if (RandomInt(0, 1) > value) return
    
    CustomAttributes.TakeDamageTable.UberOnDamageTaken(params) {

    }
}

function CustomAttributes::TurnToIce(player, item) {

    local wep = PopExtUtil.HasItemInLoadout(player, item)
    if (wep == null) return

    //cleanup before spawning a new one
    for (local knife; knife = FindByClassname(knife, "tf_weapon_knife");)
        if (PopExtUtil.GetItemIndex(knife) == ID_SPY_CICLE && knife.GetEFlags() & EFL_USER)
            EntFireByHandle(knife, "Kill", "", -1, null, null)
        

    local freeze_proxy_weapon = CreateByClassname("tf_weapon_knife")
    SetPropInt(freeze_proxy_weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", ID_SPY_CICLE)
    SetPropBool(freeze_proxy_weapon, "m_AttributeManager.m_Item.m_bInitialized", true)
    freeze_proxy_weapon.AddEFlags(EFL_USER)
    SetPropEntity(freeze_proxy_weapon, "m_hOwner", player)
    freeze_proxy_weapon.DispatchSpawn()
    freeze_proxy_weapon.DisableDraw()
    
    // Add the attribute that creates ice statues
    freeze_proxy_weapon.AddAttribute("freeze backstab victim", 1.0, -1.0)

    CustomAttributes.TakeDamageTable.TurnToIce <- function(params) {

        local attacker = params.attacker
        if (PopExtUtil.HasItemInLoadout(attacker, item) == null) return true

        local victim = params.const_entity
        if (victim.IsPlayer() && attacker == player && params.damage >= victim.GetHealth())
        {
            victim.TakeDamageCustom(attacker, victim, freeze_proxy_weapon, Vector(), Vector(), params.damage, params.damage_type, params.damage_custom | TF_DMG_CUSTOM_BACKSTAB)

            // I don't remember why this is needed but it's important
            local ragdoll = GetPropEntity(victim, "m_hRagdoll")
            if (ragdoll) SetPropInt(ragdoll, "m_iDamageCustom", 0)
            params.early_out = true
        }
    }
}

function CustomAttributes::TeleporterSpeedBoost(player, item) {

    local scope = player.GetScriptScope()
    scope.speedboostteleporter <- true

    CustomAttributes.PlayerTeleportTable.TeleporterSpeedBoost <- function(params) {

        if (params.builderid != PopExtUtil.GetPlayerUserID(player)) return
        local teleportedplayer = GetPlayerFromUserID(params.userid)

        if ("speedboostteleporter" in scope && scope.speedboostteleporter) teleportedplayer.AddCondEx(TF_COND_SPEED_BOOST, value, player)
    }
}

function CustomAttributes::CanBreatheUnderwater(player, item) {
    
    local painfinished = GetPropInt(player, "m_PainFinished")

    player.GetScriptScope().PlayerThinkTable.CanBreatheUnderwater <- function() {

        if (player.GetWaterLevel() == 3) {
            SetPropFloat(player, "m_PainFinished", FLT_MAX)
            return
        }
        SetPropFloat(player, "m_PainFinished", 0.0)
    }
}
function CustomAttributes::MultSwimSpeed(player, item, value = 1.25) {

    //local speedmult = 1.254901961
    local maxspeed = GetPropFloat(player, "m_flMaxspeed")

    player.GetScriptScope().PlayerThinkTable.MultSwimSpeed <- function() {
        
        if (player.GetWaterLevel() == 3) 
        {
            SetPropFloat(player, "m_flMaxspeed", maxspeed * value)
            return
        }
        SetPropFloat(player, "m_flMaxspeed", maxspeed)
    }
}

function CustomAttributes::LastShotCrits(player, item, value = -1) {

    local wep = PopExtUtil.HasItemInLoadout(player, item)
    if (wep == null) return

    local nextattack = 0.0
    
    player.GetScriptScope().PlayerThinkTable.LastShotCrits <- function() {

        if (wep == null || nextattack == GetPropFloat(wep, "m_flNextPrimaryAttack")) return

        nextattack = GetPropFloat(wep, "m_flNextPrimaryAttack")
        try {

            if (wep.Clip1() != 1)
            {
                player.RemoveCondEx(COND_CRITBOOST, true)
                return
            }
            player.AddCondEx(COND_CRITBOOST, value, null)
        } catch(e) printl(e)
    }
}

function CustomAttributes::WetImmunity(player, item) {

    local wetconds = [TF_COND_MAD_MILK, TF_COND_URINE, TF_COND_GAS]

    player.GetScriptScope().PlayerThinkTable.WetImmunity <- function() {
        foreach (cond in wetconds)
            if (player.InCond(cond))
                player.RemoveCondEx(cond, true)
    }
}

function CustomAttributes::AddAttr(player, attr = "", value = 0, item = null) {

    //TODO: set up error handler
    if (!(attr in CustomAttributes.Attrs)) return

    local scope = player.GetScriptScope()
    if (!("attribinfo" in scope)) scope.attribinfo <- {}

	switch(attr) {

        case "fires milk bolt":
            CustomAttributes.FireMilkBolt(player, item, value)
            scope.attribinfo[attr] <- format("Secondary attack: fires a bolt that applies milk for %d seconds.", value)
        break

        case "mod teleporter speed boost":
            CustomAttributes.TeleporterSpeedBoost(player, item)
            scope.attribinfo[attr] <- format("Teleporters grant a speed boost for %f seconds", value)
        break

        case "set turn to ice":
            CustomAttributes.TurnToIce(player, item)
            scope.attribinfo[attr] <- format("On Kill: Turn victim to ice.", value)
        break

        case "mult teleporter recharge rate":
            CustomAttributes.TeleporterRechargeTime(player, item, value)
            scope.attribinfo[attr] <- format("Teleporter recharge rate multiplied by %f", value)
        break

        case "melee cleave attack":
            CustomAttributes.MeleeCleaveAttack(player, item, value)
            scope.attribinfo[attr] <- "On Swing: Weapon hits multiple targets"
        break

        case "last shot crits":
            CustomAttributes.LastShotCrits(player, item)
            scope.attribinfo[attr] <- "Crit boost on last shot"

        break

        case "wet immunity": 
            CustomAttributes.WetImmunity(player, item)
            scope.attribinfo[attr] <- "Immune to jar effects"
        break
        
        case "can breathe under water":
            CustomAttributes.CanBreatheUnderwater(player, item)
            scope.attribinfo[attr] <- "Player can breathe underwater"
        break

        case "mult swim speed":
            CustomAttributes.MultSwimSpeed(player, item, value)
            scope.attribinfo[attr] <- format("Swimming speed multiplied by %f", value.tofloat())
        break
        
        case "teleport instead of die":
            CustomAttributes.TeleportInsteadOfDie(player, item, value)
            scope.attribinfo[attr] <- format("%d percent chance of teleporting to spawn with 1 health instead of dying", (value.tofloat() * 100).tointeger())
        break
        
        case "mult dmg vs same class":
            CustomAttributes.DmgVsSameClass(player, item, value)
            scope.attribinfo[attr] <- format("Damage versus %s multiplied by %f", PopExtUtil.Classes[player.GetPlayerClass()], value.tofloat())
        break
    }

    local cooldowntime = 3.0

    local scope = player.GetScriptScope()
    scope.PlayerThinkTable.ShowAttribInfo <- function() {

        if (!player.IsInspecting() || Time() < cooldowntime) return

        local formatted = ""

        foreach (desc, attr in scope.attribinfo)
            if (!formatted.find(attr))
                formatted += format("%s:\n\n%s\n\n\n", desc, attr)

        printl(formatted.len())
        PopExtUtil.ShowHudHint(formatted, player, 3.0 - SINGLE_TICK)

        cooldowntime = Time() + 3.0
    }
}

//obsolete, implemented into item/playerattribs
// function CustomAttrs(attrs = {}) {
//     CustomAttributes.SpawnHookTable.ApplyCustomAttribs <- function(params)
//     {
//         local player = GetPlayerFromUserID(params.userid)
//         if (player.IsBotOfType(1337)) return
//         foreach (k, v in attrs)
//             if (v.len() == 1)
//                 CustomAttributes.AddAttr(player, k, v[0])
//             else 
//                 CustomAttributes.AddAttr(player, k, v[0], v[1])
//     }
// }