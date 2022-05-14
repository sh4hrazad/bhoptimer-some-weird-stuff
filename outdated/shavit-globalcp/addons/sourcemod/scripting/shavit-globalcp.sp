/**
 * Module of shavit's Timer - Global Checkpoints
 * by: Shahrazad
 */

#include <sourcemod>
#include <shavit/core>
#include <shavit/checkpoints>
#include <shavit/zones>
#include <multicolors>
#include <sdktools>

#define GLOBALCP_NAME		"[shavit] Global Checkpoints"
#define GLOBALCP_AUTHOR		"Shahrazad"
#define GLOBALCP_DESCRIPTION	"Show a menu that lists checkpoints that all players saved."
#define GLOBALCP_VERSION	SHAVIT_VERSION

#pragma newdecls required
#pragma semicolon 1

enum struct global_cp_cache_t {
	cp_cache_t cpcache;
	char sPlayerName[32];
	int iCheckpointNumber;
	int iSaveTime;
}

ConVar gCV_Checkpoints = null;
ConVar gCV_MaxCP = null;
ConVar gCV_MaxCP_Segmented = null;

ArrayList gA_GlobalCheckpoints = null;

int gI_CheckpointsSaved;
int gI_CheckpointSelected[MAXPLAYERS + 1];

public Plugin myinfo = {
	name		=	GLOBALCP_NAME,
	author		=	GLOBALCP_AUTHOR,
	description	=	GLOBALCP_DESCRIPTION,
	version		=	GLOBALCP_VERSION
}

#include "shavit-globalcp/checkpoints.sp"
#include "shavit-globalcp/commands.sp"
#include "shavit-globalcp/menu.sp"
#include "shavit-globalcp/misc.sp"

/* == [ INITIALIZE ] == */

public void OnPluginStart() {
	LoadTranslations("shavit-globalcp.phrases");
	RegisterCommand();
	InitList(true);
	GetCvar();
}

public void OnMapStart() {
	InitList();
}

public void OnMapEnd() {
	delete gA_GlobalCheckpoints;
}

/* == [ FUNCTIONS ] == */

/* -- Save checkpoints to gA_GlobalCheckpoints -- */
public void Shavit_OnCheckpointCacheSaved(int client, cp_cache_t cpcache, int index, int target) {
	if (index == -1) // dont save persistent cpcache
		return;

	OnCheckpointCacheSaved(client, cpcache);
}

/* -- Teleport the player to the global checkpoint that is selected -- */
public bool TeleportToGlobalCheckpoint(int client, int index) {
	return OnTeleportToGlobalCheckpoint(client, index);
}

/* -- Save the global checkpoint to the client's checkpoint menu -- */
public bool SaveGlobalCheckpointForPlayer(int client, int index) {
	return OnSaveGlobalCheckpointForPlayer(client, index);
}

/* -- Save a customized checkpoint -- */
public int SaveLocation(int client, char sSavelocInfo[9][8]) {
	return OnSaveLocation(client, sSavelocInfo);
}
