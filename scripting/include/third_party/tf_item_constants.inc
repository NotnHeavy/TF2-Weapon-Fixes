//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined __tf_item_constants_h
    #endinput
#endif
#define __tf_item_constants_h

#define INVALID_ITEM_DEF_INDEX -1

// Slots for items within loadouts
enum
{
	LOADOUT_POSITION_INVALID = -1,

	// Weapons & Equipment
	LOADOUT_POSITION_PRIMARY = 0,
	LOADOUT_POSITION_SECONDARY,
	LOADOUT_POSITION_MELEE,
	LOADOUT_POSITION_UTILITY,
	LOADOUT_POSITION_BUILDING,
	LOADOUT_POSITION_PDA,
	LOADOUT_POSITION_PDA2,

	// Wearables. If you add new wearable slots, make sure you add them to IsWearableSlot() below this.
	LOADOUT_POSITION_HEAD,
	LOADOUT_POSITION_MISC,

	// other
	LOADOUT_POSITION_ACTION,

	// More wearables, yay!
	LOADOUT_POSITION_MISC2,

	// taunts
	LOADOUT_POSITION_TAUNT,
	LOADOUT_POSITION_TAUNT2,
	LOADOUT_POSITION_TAUNT3,
	LOADOUT_POSITION_TAUNT4,
	LOADOUT_POSITION_TAUNT5,
	LOADOUT_POSITION_TAUNT6,
	LOADOUT_POSITION_TAUNT7,
	LOADOUT_POSITION_TAUNT8,

	CLASS_LOADOUT_POSITION_COUNT,
};

enum
{
	ACCOUNT_LOADOUT_POSITION_ACCOUNT1,
	ACCOUNT_LOADOUT_POSITION_ACCOUNT2,
	ACCOUNT_LOADOUT_POSITION_ACCOUNT3,

	ACCOUNT_LOADOUT_POSITION_COUNT,
};

#define	LOADOUT_MAX_WEARABLES_COUNT ( 8 /* !!! -- LOADOUT_POSITION_COUNT - 3 */ )

stock bool IsMiscSlot( int iSlot )
{
	return iSlot == LOADOUT_POSITION_MISC
		|| iSlot == LOADOUT_POSITION_MISC2
		|| iSlot == LOADOUT_POSITION_HEAD
		;
}

stock bool IsBuildingSlot( int iSlot )
{
	return iSlot == LOADOUT_POSITION_BUILDING;
}

stock bool IsTauntSlot( int iSlot )
{
	return iSlot == LOADOUT_POSITION_TAUNT
		|| iSlot == LOADOUT_POSITION_TAUNT2
		|| iSlot == LOADOUT_POSITION_TAUNT3
		|| iSlot == LOADOUT_POSITION_TAUNT4
		|| iSlot == LOADOUT_POSITION_TAUNT5
		|| iSlot == LOADOUT_POSITION_TAUNT6
		|| iSlot == LOADOUT_POSITION_TAUNT7
		|| iSlot == LOADOUT_POSITION_TAUNT8;
}

stock bool IsWearableSlot( int iSlot ) 
{
	return iSlot == LOADOUT_POSITION_HEAD
		|| iSlot == LOADOUT_POSITION_MISC
		|| iSlot == LOADOUT_POSITION_ACTION
		|| IsMiscSlot( iSlot )
		|| IsTauntSlot( iSlot );
}

stock bool IsQuestSlot( int iSlot )
{
	return iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT1
		|| iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT2
		|| iSlot == ACCOUNT_LOADOUT_POSITION_ACCOUNT3;
}

stock bool IsValidItemSlot( int iSlot )
{
	return iSlot > LOADOUT_POSITION_INVALID && iSlot < CLASS_LOADOUT_POSITION_COUNT;
}

stock bool IsValidPickupWeaponSlot( int iSlot )
{
	return iSlot == LOADOUT_POSITION_PRIMARY
		|| iSlot == LOADOUT_POSITION_SECONDARY
		|| iSlot == LOADOUT_POSITION_MELEE;
}

// The total number of loadouts to track for each player.
// Right now, hardcoded to match TF's 10 classes.
#define LOADOUT_COUNT					(10+1)	// 0th class is undefined

// Halloween! (Shared by GC and game client.)
enum
{
	kHalloweenMap_MannManor,
	kHalloweenMap_Viaduct,
	kHalloweenMap_Lakeside,
	kHalloweenMap_Hightower,

	kHalloweenMapCount
};

enum
{
	kHalloweenGiftMeta_IsUnderworldOnViaduct_DEPRECATED		= 0x01,
};