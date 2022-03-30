// !!! Please make sure that your timer has been updated to 3.2.0 or higher, or stuff may break.

/* -- Includes -- */
// base
#include <sourcemod>

// misc
#include <multicolors>
#include <sdktools>

// bhoptimer
#include <shavit/core>
#include <shavit/checkpoints>

// coding rule
#pragma newdecls required
#pragma semicolon 1

/* -- Variable & Structure Definition -- */
enum struct global_cp_cache_t {
	cp_cache_t cpcache;
	char sPlayerName[32];
	int iCheckpointNumber;  // begins from 1
	int iSaveTime;
}

ConVar gCV_MaxCP = null;
ConVar gCV_MaxCP_Segmented = null;

ArrayList gA_GlobalCheckpoints = null;

int gI_CheckpointsSaved;    // begins from 1, 0 if no checkpoints
int gI_CheckpointSelected[MAXPLAYERS + 1];

/* -- Plugin Info -- */
public Plugin myinfo = {
	name        =       "[Shavit] Global Checkpoints",
	author      =       "Shahrazad",
	description =       "Show a menu that lists checkpoints that all players saved.",
	version     =       SHAVIT_VERSION,
};

/* -- Initialization -- */
public void OnPluginStart() {
	/* -- Console Variables -- */
	RegConsoleCmd("sm_gcp", Command_GlobalCheckpoints,
		"Show a menu that lists checkpoints that all players saved.");
	RegConsoleCmd("sm_getcp", Command_GetCheckpoint,
		"Copy a checkpoint to your menu from global cps menu. Usage: sm_getcp #<global cp num>");
	
	gCV_MaxCP = FindConVar("shavit_checkpoints_maxcp");
	gCV_MaxCP_Segmented = FindConVar("shavit_checkpoints_maxcp_seg");

	if (gA_GlobalCheckpoints == null)
		gA_GlobalCheckpoints = new ArrayList(sizeof(global_cp_cache_t));
}

/* -- Reset on next map -- */
public void OnMapStart() {
	gI_CheckpointsSaved = 0;
	gA_GlobalCheckpoints = new ArrayList(sizeof(global_cp_cache_t));
}

public void OnClientDisconnect(int client) {
	gI_CheckpointSelected[client] = 0;
}

/* -- Prevent memory leak..?? -- */
public void OnPluginEnd() {
	// in case that someone re/unload the plugin?
	delete gA_GlobalCheckpoints;
}

/* -- Commands -- */
public Action Command_GlobalCheckpoints(int client, any args) {
	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}

	OpenGlobalCheckpointsMenu(client);

	return Plugin_Handled;
}

public Action Command_GetCheckpoint(int client, any args) {
	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	} else if (args < 1) {
		CPrintToChat(client, "{white}Usage: sm_getcp #<{lightgreen}global cp num{white}>");
		return Plugin_Handled;
	}

	char sArg[5];
	GetCmdArg(1, sArg, sizeof(sArg));
	int iCPNumber = StringToInt(sArg);

	if (!iCPNumber || iCPNumber > gA_GlobalCheckpoints.Length) {
		CPrintToChat(client, "{white}Checkpoint #{lightgreen}%d{white} not found.", iCPNumber);
		return Plugin_Handled;
	}

	bool iIsSaved = SaveGlobalCheckpoint(client, iCPNumber);

	if (iIsSaved) {
		// find the destination that saved the checkpoint
		int iMaxCPs = GetMaxCPs(client);
		bool bOverflow = (Shavit_GetTotalCheckpoints(client) >= iMaxCPs);
		int iSaveIndex = bOverflow ? iMaxCPs : Shavit_GetTotalCheckpoints(client);

		CPrintToChat(client, "{white}Checkpoint #{lightgreen}%d{white} -> #{lightgreen}%d{white} saved.",
			iCPNumber, iSaveIndex);
	}

	return Plugin_Handled;
}

/* -- Menu -- */
void OpenGlobalCheckpointsMenu(int client, int item = 0) {
	char sInfo[64];

	Menu hMenu = new Menu(MenuHandler_GlobalCheckpoints);
	hMenu.SetTitle("Choose a checkpoint to teleport:\n"
		... "!!! Timer will be stopped if teleporting.\n ");

	bool bIsFull = (GetMaxCPs(client) <= Shavit_GetTotalCheckpoints(client));
	bool bIsSelected = (gI_CheckpointSelected[client] != 0);

	FormatEx(sInfo, sizeof(sInfo), "Save #%d -> #%d %s",
		gI_CheckpointSelected[client],
		Shavit_GetTotalCheckpoints(client) + 1,
		bIsFull ? "(FULL)" : "");
	hMenu.AddItem("save", bIsSelected ? sInfo : "Save (Not selected)",
		(bIsFull || !bIsSelected) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	hMenu.AddItem("cpmenu", "Open CP menu");

	FormatEx(sInfo, sizeof(sInfo), "Refresh\n ");
	hMenu.AddItem("refresh", sInfo);

	if (gI_CheckpointsSaved == 0) {
		hMenu.AddItem("", "Nothing temporarily", ITEMDRAW_DISABLED);
	} else {
		int iIndex;
		char sIndex[8];

		for (iIndex = gI_CheckpointsSaved; iIndex > 0; iIndex--) {
			global_cp_cache_t checkpoint;
			gA_GlobalCheckpoints.GetArray(iIndex-1, checkpoint, sizeof(checkpoint));

			char sStyle[16];
			Shavit_GetStyleSetting(checkpoint.cpcache.aSnapshot.bsStyle, "name", sStyle, sizeof(sStyle));

			char sTimeBuffer[16];
			GetFormatedLapsedTime(checkpoint.iSaveTime, GetTime(), sTimeBuffer, sizeof(sTimeBuffer));

			// list checkpoints
			Format(sIndex, sizeof(sIndex), "%d", checkpoint.iCheckpointNumber);
			Format(sInfo, sizeof(sInfo), "#%d - %s - %s - %s",
				checkpoint.iCheckpointNumber,
				checkpoint.sPlayerName,
				sStyle,
				sTimeBuffer);
			AddMenuItem(hMenu, sIndex, sInfo);
		}
	}

	hMenu.ExitButton = true;
	hMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int MenuHandler_GlobalCheckpoints(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if (StrEqual(sInfo, "save")) {
			SaveGlobalCheckpoint(param1, gI_CheckpointSelected[param1]);
		} else if (StrEqual(sInfo, "cpmenu")) {
			FakeClientCommandEx(param1, "sm_checkpoints");
		} else if (StrEqual(sInfo, "refresh")) {
			// do nothing, just refresh the menu.
		} else {
			char sInfoGuess[8];
			int iIndex;

			for (iIndex = 1; iIndex <= gI_CheckpointsSaved; iIndex++) {
				FormatEx(sInfoGuess, sizeof(sInfoGuess), "%d", iIndex);
				if (StrEqual(sInfo, sInfoGuess)) {
					TeleportToGlobalCheckpoint(param1, iIndex);
					gI_CheckpointSelected[param1] = iIndex;
				}
			}
		}
		OpenGlobalCheckpointsMenu(param1, GetMenuSelectionPosition());
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

/* -- Save checkpoints to gA_GlobalCheckpoints -- */
public void Shavit_OnCheckpointCacheSaved(int client, cp_cache_t cache, int index, int target) {
	global_cp_cache_t checkpoint;
	checkpoint.cpcache = cache;

	// refered to Shavit_SetCheckpoint()
	if (cache.aFrames)
		checkpoint.cpcache.aFrames = cache.aFrames.Clone();
	if (cache.aEvents)
		checkpoint.cpcache.aEvents = cache.aEvents.Clone();
	if (cache.aOutputWaits)
		checkpoint.cpcache.aOutputWaits = cache.aOutputWaits.Clone();
	if (cache.customdata)
		checkpoint.cpcache.customdata = view_as<StringMap>(CloneHandle(cache.customdata));
	
	// no need to preserve it, load all cps from the menu and switch to practice mode or stop timer
	checkpoint.cpcache.iSteamID = -1;

	GetClientName(client, checkpoint.sPlayerName, sizeof(checkpoint.sPlayerName));
	checkpoint.iCheckpointNumber = gI_CheckpointsSaved + 1;
	checkpoint.iSaveTime = GetTime();

	gA_GlobalCheckpoints.PushArray(checkpoint);
	gI_CheckpointsSaved++;
}

/* -- Teleport the player to the global checkpoint that is selected -- */
bool TeleportToGlobalCheckpoint(int client, int index) {
	global_cp_cache_t checkpoint;
	gA_GlobalCheckpoints.GetArray(index - 1, checkpoint, sizeof(checkpoint));
	
	Shavit_LoadCheckpointCache(client, checkpoint.cpcache, -1, sizeof(cp_cache_t));
	Shavit_ResumeTimer(client);

	return true;
}

/* -- Save the global checkpoint to the client's checkpoint menu -- */
bool SaveGlobalCheckpoint(int client, int index) {
	if (Shavit_GetTotalCheckpoints(client) == GetMaxCPs(client)) {
		CPrintToChat(client, "{white}Can't save the checkpoint because your checkpoint list is {lightgreen}full{white}!");

		return false;
	}

	global_cp_cache_t checkpoint;
	gA_GlobalCheckpoints.GetArray(index - 1, checkpoint, sizeof(checkpoint));

	Shavit_SetCheckpoint(client, -1, checkpoint.cpcache, sizeof(cp_cache_t), false);
	Shavit_SetCurrentCheckpoint(client, Shavit_GetTotalCheckpoints(client));
	
	return true;
}

/* -- Misc code -- */
public int GetMaxCPs(int client) {
	return Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "segments") ?
		gCV_MaxCP_Segmented.IntValue : gCV_MaxCP.IntValue;
}

public void GetFormatedLapsedTime(int timestamp, int currentTime, char[] buffer, int size) {
	int iLapsedTime = currentTime - timestamp;

	if (iLapsedTime < 10)
		FormatEx(buffer, size, "Just now");
	else if (iLapsedTime >= 10 && iLapsedTime < 61)
		FormatEx(buffer, size, "%d seconds ago", iLapsedTime);
	else if (iLapsedTime >= 61 && iLapsedTime < 3601)
		FormatEx(buffer, size, "%d %s ago", iLapsedTime / 60, iLapsedTime / 60 == 1 ? "minute" : "minutes");
	else
		FormatEx(buffer, size, "long long ago...");
}
