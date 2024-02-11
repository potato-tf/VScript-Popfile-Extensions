::MissionAttributes <- {};              // MissionAttributes namespace.
MissionAttributes.CurrAttrs <- [];       // Array storing currently modified attributes.
MissionAttributes.DebugText <- false;     // Print debug text.
MissionAttributes.RaisedParseError <- false;

local pumpkinIndex = PrecacheModel("models/props_halloween/pumpkin_loot.mdl");
local crumpkinCond = Constants.ETFCond.TF_COND_CRITBOOSTED_PUMPKIN;
// Mission Attribute Functions
// =========================================================
// Function is called in popfile by mission maker to modify mission attributes.
function MissionAttributes::MissionAttr(attr, value = 0)
{
    local success = true;
    switch(attr) {

    // =========================================================

    case "ForceHoliday":
    // Replicates sigsegv-mvm: ForceHoliday.
    // Forces a tf_holiday for the mission.
    // Supported Holidays are:
    //  0 - None
    //  1 - Birthday
    //  2 - Halloween
    //  3 - Christmas
    // @param Holiday       Holiday number to force.
    // @error TypeError     If type is not an integer.
    // @error IndexError    If invalid holiday number is passed.
        // Error Handling
        if (type(value) != "integer") {RaiseTypeError(attr, "int"); success = false; break;}
        if (value < 0 || value > 2) {RaiseIndexError(attr); success = false; break;}

        // Set Holiday logic
        Convars.SetValue("tf_forced_holiday", value);
        if (value == 0) break;

        local ent = Entities.FindByName(null, "MissionAttrHoliday");
        if (ent != null) ent.Kill();
        SpawnEntityFromTable("tf_logic_holiday", { targetname = "MissionAttrHoliday", holiday_type = value });

        break;

    // ========================================================

    case "NoCritPumpkins":

        function MissionAttributes::PopExt_OnGameEvent_player_death(_)
        {
            for (local pumpkin; pumpkin = Entities.FindByClassname(pumpkin, "tf_ammo_pack");)
                if (pumpkin.GetModelIndex() == pumpkinIndex)
                    EntFireByHandle(pumpkin, "Kill", "", -1, null, null); //can't do .Kill() in the loop

            for (local i = 1, player; i <= MaxClients(); i++)
                if (player = PlayerInstanceFromIndex(i), player && player.InCond(33)) //TF_COND_CRITBOOSTED_PUMPKIN
                    EntFireByHandle(player, "RunScriptCode", "self.RemoveCond(33)", -1, null, null);
        }
        break;

    // =========================================================

    case "NoReanimators":

        function MissionAttributes::PopExt_OnGameEvent_player_death(params)
        {
            if (GetPlayerFromUserID(params.userid).IsBotOfType(1337)) return;

            for (local revivemarker; revivemarker = Entities.FindByClassname(revivemarker, "entity_revive_marker");)
                revivemarker.Kill();
        }
        break;

    // =========================================================

    case "ZombiesNoWave666":
        NetProps.SetPropInt(__objectiveresource, "m_nMvMEventPopfileType", 0);
        break;

    // =========================================================

    //all of these could just be set directly in the pop easily, however popfile's have a 4096 character limit for vscript so might as well save space
    case "DisableRefunds":

        Convars.SetValue("tf_mvm_respec_enabled", 0);
        break;

    case "RefundLimit":

        Convars.SetValue("tf_mvm_respec_enabled", 1);
        Convars.SetValue("tf_mvm_respec_limit", value);
        break;

    case "RefundGoal":
        Convars.SetValue("tf_mvm_respec_enabled", 1);
        Convars.SetValue("tf_mvm_respec_credit_goal", value);
        break;

    case "FixedBuybacks":
        Convars.SetValue("tf_mvm_buybacks_method", 1);
        break;

    case "BuybacksPerWave":
        Convars.SetValue("tf_mvm_buybacks_per_wave", value);
        break;

    case "DeathPenalty":
        Convars.SetValue("tf_mvm_death_penalty", value);
        break;

    case "BonusRatioHalf":
        Convars.SetValue("tf_mvm_currency_bonus_ratio_min", value);
        break;

    case "BonusRatioFull":
        Convars.SetValue("tf_mvm_currency_bonus_ratio_max", value);
        break;

    case "UpgradeFile":
        DoEntFire("tf_gamerules", "SetCustomUpgradesFile", value, -1, null, null);
        break;

    case "FlagEscortCount":
        Convars.SetValue("tf_bot_flag_escort_max_count", value);
        break;

    // =========================================================

    case "SniperHideLasers":
        local think = SpawnEntityFromTable("logic_relay", {});
        function KillLasers()
        {
            for (local dot; dot = Entities.FindByClassname(dot, "env_sniperdot");)
                if (dot.GetOwner().GetTeam() == 3)
                    EntFireByHandle(dot, "Kill", "", -1, null, null);
        }
        think.ValidateScriptScope();
        think.GetScriptScope().KillLasers <- KillLasers;
        AddThinkToEnt(think, "KillLasers");

    // =========================================================
    case "NoBusterFriendlyFire":
        function MissionAttributes::PopExt_OnScriptHook_OnTakeDamage(params)
        {
            local attacker = params.attacker, victim = params.const_entity;
            if (IsPlayer(victim) && IsPlayerABot(attacker) && IsPlayerABot(victim) && victim.GetTeam() == attacker.GetTeam() )
                return false;
        }

    // Don't add attribute to clean-up list if it could not be found.
    default:
        ParseError(format("Could not find mission attribute '%s'", attr));
        success = false;

    }

    // Add attribute to clean-up list if its modification was successful.
    if (success)
    {
        DebugLog(format("Added mission attribute %s", attr));
        MissionAttributes.CurrAttrs.append(attr);
    }

}

// Allow calling MissionAttributes::MissionAttr() directly with MissionAttr().
function MissionAttr(attr, value)
{
    MissionAttr.call(MissionAttributes, attr, value)
}

// Clean-up Functions
// =========================================================
// Function runs the appropriate clean-up method for the provided attribute.
function MissionAttributes::DoCleanupMethod(attr)
{
    switch(attr) {
    case "ForceHoliday":
        // tf_logic_holiday will be removed by the game.
        Convars.SetValue("tf_forced_holiday", 0);
        break;
    default:
        // Raise an exception if clean-up method is missing
        RaiseException(format("Clean-up method not found for %s", attr));
    }

    DebugLog(format("Cleaned up mission attribute %s", attr));
}

// Hook first wave init to run clean-up.
function MissionAttributes::OnGameEvent_teamplay_round_start(params)
{
    ResetDefaults();
    this = {};
}

// Hook all wave inits to reset parsing error counter.
function MissionAttributes::recalculate_holidays(_)
{
    if (GetRoundState() != 3) return;

    MissionAttributes.RaisedParseError = false;
}

// Function resets and clears all registered changed attributes.
function MissionAttributes::ResetDefaults()
{
    foreach (attr in MissionAttributes.CurrAttrs)
    {
        DoCleanupMethod(attr);
    }
    MissionAttributes.CurrAttrs.clear();
}

// Logging Functions
// =========================================================
// Generic debug message that is visible if PrintDebugText is true.
// Example: Print a message that the script is working as expected.
function MissionAttributes::DebugLog(LogMsg)
{
    if (MissionAttributes.DebugText)
    {
        ClientPrint(null, 2, format("missionattributes.nut: %s.", LogMsg));
    }
}

// Raises an error if the user passes an index that is out of range.
// Example: Allowed values are 1-2, but user passed 3.
function MissionAttributes::RaiseIndexError(attr) ParseError(format("Index out of range for %s", attr));

// Raises an error if the user passes an argument of the wrong type.
// Example: Allowed values are strings, but user passed a float.
function MissionAttributes::RaiseTypeError(attr, type) ParseError(format("Bad type for %s (should be %s)", attr, type));

// Raises a template parsing error, if nothing else fits.
function MissionAttributes::ParseError(ErrorMsg)
{
    if (!MissionAttributes.RaisedParseError)
    {
        MissionAttributes.RaisedParseError = true;
        ClientPrint(null, 3, "\x08FFB4B4FFIt is possible that a parsing error has occured. Check console for details.");
    }
    ClientPrint(null, 2, format("missionattributes.nut ERROR: %s.", ErrorMsg));
}

// Raises an exception.
// Example: Script modification has not been performed correctly. User should never see one of these.
function MissionAttributes::RaiseException(ExceptionMsg)
{
    Assert(false, format("missionattributes.nut EXCEPTION: %s.", ExceptionMsg));
}

// =========================================================
// Register MissionAttributes callbacks.
__CollectGameEventCallbacks(MissionAttributes);