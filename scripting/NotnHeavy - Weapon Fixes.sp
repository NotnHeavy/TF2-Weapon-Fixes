//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// This uses my Weapon Manager plugin:
// https://github.com/NotnHeavy/TF2-Weapon-Manager

#pragma semicolon true 
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#include <third_party/weapon_manager>

#define PLUGIN_NAME "NotnHeavy - Weapon Fixes"

//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "NotnHeavy",
    description = "Used alongside Weapon Manager to provide some fixes for weapons.",
    version = "1.0.0",
    url = "https://github.com/NotnHeavy/TF2-Weapon-Fixes"
};

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //

enum OSType
{
    OSTYPE_WINDOWS,
    OSTYPE_LINUX
};
static OSType g_eOS;

enum struct player_t
{
    int m_hShield;
}
static player_t g_PlayerData[MAXPLAYERS + 1];

static StringMap g_AmmoTable;

static Handle SDKCall_CTFWearableDemoShield_DoSpecialAction;

static DynamicDetour DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed;

static int CUtlVector_m_Size;

static any CTFPlayerShared_UpdateChargeMeter_ClassCheck;
static int CTFPlayerShared_UpdateChargeMeter_OldBuffer[6];

static ConVar tf_max_charge_speed;

static Handle sync;

//////////////////////////////////////////////////////////////////////////////
// INITIALISATION                                                           //
//////////////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
    // Load translations file for SM errors.
    LoadTranslations("common.phrases");
    PrintToServer("--------------------------------------------------------");

    // Load gamedata (this uses the gamedata from my Randomizer plugin).
    GameData config = LoadGameConfigFile(PLUGIN_NAME);
    if (!config)
        SetFailState("Failed to load gamedata from \"%s\".", PLUGIN_NAME);

    // Set up SDKCalls.
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWearableDemoShield::DoSpecialAction()");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    SDKCall_CTFWearableDemoShield_DoSpecialAction = EndPrepSDKCall();

    // Set up detours.
    DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed = DynamicDetour.FromConf(config, "CTFPlayer::TeamFortress_CalculateMaxSpeed()");
    DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed.Enable(Hook_Pre, CTFPlayer_TeamFortress_CalculateMaxSpeed);

    // Set offsets.
    CUtlVector_m_Size = config.GetOffset("CUtlVector::m_Size");

    // Get the OS type.
    g_eOS = view_as<OSType>(config.GetOffset("OSType"));

    // Patch CTFPlayerShared::UpdateChargeMeter() so that no class checks take place.
    any address = config.GetMemSig("CTFPlayerShared::UpdateChargeMeter()");
    address += config.GetOffset("CTFPlayerShared::UpdateChargeMeter()::ClassCheck");
    if (g_eOS == OSTYPE_WINDOWS)
    {
        // Just NOP the JZ instruction on Windows.
        for (int i = 0; i < 6; ++i)
        {
            CTFPlayerShared_UpdateChargeMeter_OldBuffer[i] = LoadFromAddress(address + i, NumberType_Int8);
            StoreToAddress(address + i, 0x90, NumberType_Int8);
        }
    }
    else
    {
        // For some reason Linux is a lot more complicated.
        // Change the CALL instruction to a MOV EAX, 1 and cache the remaining byte.
        static char MOV_EAX_1[] = "\xB8\x01\x00\x00\x00";
        for (int i = 0; i < sizeof(MOV_EAX_1) - 1; ++i)
        {
            CTFPlayerShared_UpdateChargeMeter_OldBuffer[i] = LoadFromAddress(address + i, NumberType_Int8);
            StoreToAddress(address + i, MOV_EAX_1[i], NumberType_Int8);
        }
        CTFPlayerShared_UpdateChargeMeter_OldBuffer[5] = LoadFromAddress(address + 5, NumberType_Int8);
    }
    CTFPlayerShared_UpdateChargeMeter_ClassCheck = address;

    // Delete the gamedata handle.
    delete config;

    // Initialize the ammo table.
    g_AmmoTable = new StringMap();

    // Read the given config and load all max ammo values.
    char gamedata_path[PLATFORM_MAX_PATH];
    Format(gamedata_path, sizeof(gamedata_path), "addons/sourcemod/configs/%s.cfg", PLUGIN_NAME);
    KeyValues kv = new KeyValues("AmmoTable");
    kv.ImportFromFile(gamedata_path);

    // Walk through each key.
    char section[NAME_LENGTH];
    int value;
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            // Add this to the ammo table.
            kv.GetSectionName(section, sizeof(section));
            value = kv.GetNum(NULL_STRING);
            g_AmmoTable.SetValue(section, value);
            PrintToServer("- \"%s\" given max ammo %i", section, value);
        } 
        while (kv.GotoNextKey(false));
    }
    PrintToServer("");

    // Delete the gamedata KeyValues handle.
    delete kv;

    // Call OnClientPutInServer().
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
            OnClientPutInServer(i);
    }

    // Set up ConVars.
    tf_max_charge_speed = FindConVar("tf_max_charge_speed");

    // Set up the HUD text synchroniser.
    sync = CreateHudSynchronizer();

    // Print to server.
    PrintToServer("\"%s\" has loaded.\n--------------------------------------------------------", PLUGIN_NAME);
}

public void OnPluginEnd()
{
    // Revert the CTFPlayerShared::UpdateChargeMeter() patch.
    for (int i = 0; i < sizeof(CTFPlayerShared_UpdateChargeMeter_OldBuffer); ++i)
        StoreToAddress(CTFPlayerShared_UpdateChargeMeter_ClassCheck, CTFPlayerShared_UpdateChargeMeter_OldBuffer[i], NumberType_Int8);
}

//////////////////////////////////////////////////////////////////////////////
// WEAPON CODE                                                              //
//////////////////////////////////////////////////////////////////////////////

// Validate whether a user has a shield or not.
public void ValidateShield(int client)
{
    // Walk through their wearables to see if they have a shield.
    g_PlayerData[client].m_hShield = INVALID_ENT_REFERENCE;
    any m_hMyWearables = view_as<any>(GetEntityAddress(client)) + FindSendPropInfo("CTFPlayer", "m_hMyWearables");
    for (int index = 0, size = LoadFromAddress(m_hMyWearables + CUtlVector_m_Size, NumberType_Int32); index < size; ++index)
    {
        // Get the wearable.
        int handle = LoadFromAddress(LoadFromAddress(m_hMyWearables, NumberType_Int32) + index * 4, NumberType_Int32);
        int wearable = EntRefToEntIndex(handle | (1 << 31));
        if (wearable == INVALID_ENT_REFERENCE)
            continue;

        // Check if the wearable is about to be removed.
        if (GetEntityFlags(wearable) & FL_KILLME)
            continue;
        
        // Check if this is a shield.
        char classname[64];
        WeaponManager_GetWeaponClassname(wearable, classname, sizeof(classname));
        if (strcmp(classname, "tf_wearable_demoshield") != 0)
            continue;

        // Store a reference to the shield.
        g_PlayerData[client].m_hShield = EntIndexToEntRef(wearable);

        // Finish.
        break;
    }
}

//////////////////////////////////////////////////////////////////////////////
// FORWARDS                                                                 //
//////////////////////////////////////////////////////////////////////////////

public void OnClientPutInServer(int client)
{
    g_PlayerData[client].m_hShield = INVALID_ENT_REFERENCE;
}

// Find out whether the user has a shield or not after loadout construction.
public void WeaponManager_OnLoadoutConstructionPost(int client, bool spawn)
{
    ValidateShield(client);
}

// Find out whether the user has a shield or not after being assigned a new weapon.
public void WeaponManager_OnWeaponSpawnPost(int client, int weapon, bool isCWX, bool isFake)
{
    ValidateShield(client);
}

// Walk through the player's actions and check if they are using their attack3 bind.
// If so, check if they have a shield and trigger its charge mechanism.
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    // Is the player holding their attack3 bind?
    if (buttons & IN_ATTACK3 && IsPlayerAlive(client) && IsValidEntity(g_PlayerData[client].m_hShield))
        SDKCall(SDKCall_CTFWearableDemoShield_DoSpecialAction, g_PlayerData[client].m_hShield, client);
    return Plugin_Continue;
}

// If the player has a shield and they are not Demoman, show their charge.
public void OnGameFrame()
{
    // Walk through each client.
    for (int i = 1; i <= MaxClients; ++i)
    {
        // Check if the client is in-game and that they have a shield.
        if (IsClientInGame(i) && TF2_GetPlayerClass(i) != TFClass_DemoMan && IsValidEntity(g_PlayerData[i].m_hShield))
        {
            // Get the player's charge meter and display it.
            // TODO: work on special ability system using framework and array in player data
            float charge = GetEntPropFloat(i, Prop_Send, "m_flChargeMeter");
            SetHudTextParams(0.05, 0.05, 0.5, 255, 255, 255, 0, 0, 6.0, 0.0, 0.0);
            ShowSyncHudText(i, sync, "Recharge: %i%", RoundToFloor(charge));
        }
    }
}

//////////////////////////////////////////////////////////////////////////////
// DHOOKS                                                                   //
//////////////////////////////////////////////////////////////////////////////

// Pre-call CTFPlayer::TeamFortress_CalculateMaxSpeed().
// If the player is charging and they are not a Demoman, set their speed to be the
// max charge speed.
static MRESReturn CTFPlayer_TeamFortress_CalculateMaxSpeed(int client, DHookReturn returnValue, DHookParam parameters)
{
    if (IsClientInGame(client) && TF2_GetPlayerClass(client) != TFClass_DemoMan && TF2_IsPlayerInCondition(client, TFCond_Charging))
    {
        returnValue.Value = tf_max_charge_speed.FloatValue;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

public Action WeaponManager_OnGetMaxAmmo(int client, int type, TFClassType class, int weapon, int& maxAmmo)
{
    // Validate the weapon
    if (!IsValidEntity(weapon))
        return Plugin_Continue;

    // Get the entity classname of the weapon.
    char classname[ENTITY_NAME_LENGTH];
    WeaponManager_GetWeaponClassname(weapon, classname, sizeof(classname));

    // Check if there exists a definition in the ammo table for this classname.
    int ammo;
    if (!g_AmmoTable.GetValue(classname, ammo))
        return Plugin_Continue;

    // Set the max ammo and return.
    maxAmmo = ammo;
    return Plugin_Changed;
}