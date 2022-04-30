/**
 * Module of shavit's timer - Relay
 *
 * note: you have to *delete* all relay files existed if you do so or unload plugins that used customdata,
 * 	 or stuff will break
 */

#include <sourcemod>
#include <sdktools>
#include <shavit/core>
#include <shavit/checkpoints>
#include <eventqueuefix>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define RELAY_FOLDER_PATH "/data/relay/"
#define SEGMENTED_CPS 3 // too holy shit big for segmented cps
#define CELLS_PER_FRAME 10
#define CELLS_PER_EVENT 4 // +384 for char wtf
#define CELLS_PER_ENTITY 2

// (ˊ;ω;`)
#define HOW_TO_DO_IT -1

public Plugin myinfo = {
	name = "[shavit] Relay",
	author = "Shahrazad",
	description = "Save players' timer status on map changes.",
	version = "a1"
};

/**
 * Relay 条件:
 * 	玩家计时过程中更换地图 (或关闭服务器)
 *	(暂不考虑一张图中有多个 Track 或 Style 的 Relay)
 *
 * PS: 如果换的图和上一张一样, 只需保存 Relay, 不需要打开 Relay 菜单 (玩家复活后会自动恢复计时与位置)
 */

enum struct relay_data_t {	// similar as bhoptimer's persistent_data_t
	int iSteamID;
	int iTimesTeleported;
	int iCurrentCheckpoint;
	ArrayList aCheckpoints;	// 或许只需要保存 segmented (前 n 个) 和 kz 模式的就行
	cp_cache_t cpcache;
}

relay_data_t gA_RelayData[MAXPLAYERS + 1];

char gS_RelayFolder[PLATFORM_MAX_PATH];
char gS_CurrentMap[PLATFORM_MAX_PATH];
char gS_PreviousMap[PLATFORM_MAX_PATH];

public void OnPluginStart() {
	BuildPath(Path_SM, gS_RelayFolder, sizeof(gS_RelayFolder), RELAY_FOLDER_PATH);
	CreateRelayFileFolder(gS_RelayFolder);

	HookEvent("player_spawn", EventHandler_Player_Spawn);
}

void CreateRelayFileFolder(const char[] folderPath) {
	if (!DirExists(folderPath) && !CreateDirectory(folderPath, 511)) {
		SetFailState(
			"Unable to create the folder for relay files! "
			 ... "Make sure you have file permissions."
		);
	}

	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s/test.relay", folderPath);

	File fTest = OpenFile(sPath, "wb+");
	CloseHandle(fTest);

	if (fTest == null) {
		SetFailState(
			"Unable to create a test relay file! "
			 ... "Make sure you have file permissions."
		);
	}
}

public void OnMapStart() {
	GetLowercaseMapName(gS_CurrentMap);
}

public void OnMapEnd() {
	gS_PreviousMap = gS_CurrentMap;
}

public void OnClientDisconnect(int client) {
	if (
		IsFakeClient(client)
		 || Shavit_GetTimerStatus(client) == Timer_Stopped
		 || Shavit_GetTimerStatus(client) == Timer_Running && Shavit_GetClientTime(client) == 0.0 // in start zone
	) {
		return;
	}

	CreateRelay(client);
}

void CreateRelay(int client) {
	char sPath[PLATFORM_MAX_PATH];
	GetRelayFilePath(client, gS_CurrentMap, gS_RelayFolder, sPath);

	File hFile = OpenFile(sPath, "wb+");

	hFile.WriteInt32(gA_RelayData[client].iSteamID);
	hFile.WriteInt32(gA_RelayData[client].iTimesTeleported);
	hFile.WriteInt32(gA_RelayData[client].iCurrentCheckpoint);
	
	cp_cache_t cpcache;

	bool bSegmented = Shavit_GetStyleSettingBool(client, "segmented");
	bool bKzcheckpoints = Shavit_GetStyleSettingBool(client, "kzcheckpoints");
	int iCheckpoints = Shavit_GetTotalCheckpoints(client);

	if (bSegmented || bKzcheckpoints)) {
		for (int i = (bSegmented && iCheckpoints - SEGMENTED_CPS >= 1) ? iCheckpoints - SEGMENTED_CPS : 1; i <= iCheckpoints; i++) {
			Shavit_GetCheckpoint(client, i, cpcache);

			if (cpcache.aFrames)
				cpcache.aFrames = view_as<ArrayList>(CloneHandle(cpcache.aFrames));
			if (cpcache.aEvents)
				cpcache.aEvents = view_as<ArrayList>(CloneHandle(cpcache.aEvents));
			if (cpcache.aOutputWaits)
				cpcache.aOutputWaits = view_as<ArrayList>(CloneHandle(cpcache.aOutputWaits));
			if (cpcache.customdata)
				cpcache.customdata = view_as<StringMap>(CloneHandle(cpcache.customdata));

			WriteCheckpointCacheToFile(hFile, cpcache);
			DeleteCheckpointCacheArrayList(cpcache);
		}
	}

	hFile.WriteLine("end of aCheckpoints");

	Shavit_SaveCheckpointCache(client, client, cpcache, -1);
	WriteCheckpointCacheToFile(hFile, gA_RelayData[client].cpcache);
	DeleteCheckpointCacheArrayList(cpcache);

	delete hFile;
}

public void EventHandler_Player_Spawn(Event event, const char[] name, bool dontBroadcast) {
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if (
		iClient == 0
		|| GetSteamAccountID(iClient) == 0
		|| GetClientTeam(iClient) < 2
		|| !IsPlayerAlive(iClient)
	) {
		return;
	}

	relay_data_t aRelay;

	if (FindRelay(iClient, aRelay)) {
		char sStyle[64];
		Shavit_GetStyleStrings(aRelay.cpcache.aSnapshot.bsStyle, sStyleName, sStyle, sizeof(sStyle));

		char sTrack[64];
		GetTrackName(iClient, aRelay.cpcache.aSnapshot.iTimerTrack, sTrack, sizeof(sTrack));

		AskRelayMenu(iClient, sTrack, sStyle);
	}
}

bool FindRelay(int client, relay_data_t relay) {
	Exception_NotImplemented(client);

	/*
	char sPath[PLATFORM_MAX_PATH];
	GetRelayFilePath(client, gS_CurrentMap, gS_RelayFolder, sPath);

	if (!FileExists(sPath)) {
		return false;
	}

	File hFile = OpenFile(path, "rb");

	hFile.ReadInt16(gA_RelayData[client].iSteamID);
	hFile.ReadInt8(gA_RelayData[client].iTimesTeleported);
	hFile.ReadInt8(gA_RelayData[client].iCurrentCheckpoint);
	ReadArrayFromFile(hFile, gA_RelayData[client].aCheckpoints, HOW_TO_DO_IT);
	ReadArrayFromFile(hFile, gA_RelayData[client].cpcache, sizeof(cp_cache_t));

	delete file;
	
	return true;
	*/
}

void AskRelayMenu(int client, const char[] sTrack, const char[] sStyle) {
	Menu hMenu = new Menu(MenuHandler_AskRelay);

	hMenu.SetTitle(
		"You have a relay for the map.\n"
		 ... "Do you wanna load it?\n"
		 ... "Track: %s\n"
		 ... "Style: %s\n ",
		sTrack, sStyle
	);

	hMenu.AddItem("ya", "Yes");
	hMenu.AddItem("no", "No");

	hMenu.ExitButton = false;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AskRelay(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char sInfo[3];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if (StrEqual(sInfo, "ya")) {
			LoadRelay(param1);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void LoadRelay(int client) {
	Exception_NotImplemented(client);
}

/* -- Helper -- */

void GetRelayFilePath(int client, const char[] mapName, const char[] folderPath, char sPath[PLATFORM_MAX_PATH])
{
	int iSteamID = GetSteamAccountID(client);
	FormatEx(sPath, PLATFORM_MAX_PATH, "%s/%s-%s.relay", folderPath, mapName, iSteamID);
}

// reuse code from https://github.com/shavitush/bhoptimer/tree/8f1da48e823b22a032cd5d5942759a2468dc1261
void WriteCheckpointCacheToFile(File file, cp_cache_t cpcache) {
	WriteArrayToFile(file, cpcache.fPosition, 3);
	WriteArrayToFile(file, cpcache.fAngles, 3);
	WriteArrayToFile(file, cpcache.fVelocity, 3);
	file.WriteInt32(view_as<int>(cpcache.iMoveType));
	file.WriteInt32(view_as<int>(cpcache.fGravity));
	file.WriteInt32(view_as<int>(cpcache.fSpeed));
	file.WriteInt32(view_as<int>(cpcache.fStamina));
	file.WriteInt8(view_as<int>(cpcache.bDucked));
	file.WriteInt8(view_as<int>(cpcache.bDucking));
	file.WriteInt32(view_as<int>(cpcache.fDucktime));
	file.WriteInt32(view_as<int>(cpcache.fDuckSpeed));
	file.WriteInt32(view_as<int>(cpcache.iFlags));
	WriteTimerSnapshotToFile(file, cpcache.aSnapshot);
	file.WriteString(cpcache.sTargetname, false);
	file.WriteString(cpcache.sClassname, false);
	WriteReplayFramesToFile(file, cpcache.aFrames);
	file.WriteInt32(view_as<int>(cpcache.iPreFrames));
	file.WriteInt8(view_as<int>(cpcache.bSegmented));
	file.WriteInt32(view_as<int>(cpcache.iGroundEntity));
	hFile.WriteInt32(view_as<int>(cpcache.iSteamID));
	// ArrayList aEvents;
	// ArrayList aOutputWaits;
	WriteArrayToFile(file, cpcache.vecLadderNormal, 3);
	// how to save it?
	// StringMap customdata;

	file.WriteInt8(view_as<int>(cpcache.m_bHasWalkMovedSinceLastJump));
	file.WriteInt32(view_as<int>(cpcache.m_ignoreLadderJumpTime));

#if defined MORE_LADDER_CHECKPOINT_STUFF
	WriteArrayToFile(file, cpcache.m_lastStandingPos, 3);
	WriteArrayToFile(file, m_ladderSurpressionTimer, 2);
	WriteArrayToFile(file, m_lastLadderNormal, 3);
	WriteArrayToFile(file, m_lastLadderPos, 3);
#endif
}

void WriteTimerSnapshotToFile(File file, timer_snapshot_t snapshot) {
	file.WriteInt8(view_as<int>(snapshot.bTimerEnabled));
	file.WriteInt32(view_as<int>(snapshot.fCurrentTime));
	file.WriteInt8(view_as<int>(snapshot.bClientPaused));
	file.WriteInt32(view_as<int>(snapshot.iJumps));
	file.WriteInt32(view_as<int>(snapshot.bsStyle));
	file.WriteInt32(view_as<int>(snapshot.iStrafes));
	file.WriteInt32(view_as<int>(snapshot.iTotalMeasures));
	file.WriteInt32(view_as<int>(snapshot.iGoodGains));
	file.WriteInt32(view_as<int>(snapshot.fServerTime));
	file.WriteInt32(view_as<int>(snapshot.iSHSWCombination));
	file.WriteInt32(view_as<int>(snapshot.iTimerTrack));
	file.WriteInt32(view_as<int>(snapshot.iMeasuredJumps));
	file.WriteInt32(view_as<int>(snapshot.iPerfectJumps));
	WriteArrayToFile(file, snapshot.fZoneOffset, 2);
	WriteArrayToFile(file, snapshot.fDistanceOffset, 2);
	file.WriteInt32(view_as<int>(snapshot.fAvgVelocity));
	file.WriteInt32(view_as<int>(snapshot.fMaxVelocity));
	file.WriteInt32(view_as<int>(snapshot.fTimescale));
	file.WriteInt32(view_as<int>(snapshot.iZoneIncrement));
	file.WriteInt32(view_as<int>(snapshot.iFullTicks))
	file.WriteInt32(view_as<int>(snapshot.iFractionalTicks))
	file.WriteInt8(view_as<int>(snapshot.bPracticeMode));
	file.WriteInt8(view_as<int>(snapshot.bJumped));
	file.WriteInt8(view_as<int>(snapshot.bCanUseAllKeys));
	file.WriteInt8(view_as<int>(snapshot.bOnGround));
	file.WriteInt32(view_as<int>(snapshot.iLastButtons));
	file.WriteInt32(view_as<int>(snapshot.fLastAngle));
	file.WriteInt32(view_as<int>(snapshot.iLandingTick));
	file.WriteInt32(view_as<int>(snapshot.iLastMoveType));
	file.WriteInt32(view_as<int>(snapshot.fStrafeWarning));
	WriteArrayToFile(file, snapshot.fLastInputVel, 2);
	file.WriteInt32(view_as<int>(snapshot.fplayer_speedmod));
	file.WriteInt32(view_as<int>(snapshot.fNextFrameTime));
	file.WriteInt32(view_as<int>(snapshot.iLastMoveTypeTAS));
}

void WriteReplayFramesToFile(File file, ArrayList frames) {
	int nLength = frames != null ? frames.Length : 0;
	file.WriteInt32(nLength);

	any aData[CELLS_PER_FRAME];

	for(int i = 0; i < nLength; i++)
	{
		frames.GetArray(i, aData, CELLS_PER_FRAME);
		file.Write(aData, CELLS_PER_FRAME, 4);
	}
}

void WriteArrayToFile(File file, any[] vec, int size)
{
	for(int i = 0; i < size; i++)
	{
		file.WriteInt32(view_as<int>(vec[i]));
	}
}

void ReadArrayFromFile(File file, any[] vec, int size)
{
	for(int i = 0; i < size; i++)
	{
		file.ReadInt32(vec[i]);
	}
}

void DeleteCheckpointCacheArrayList(cp_cache_t cpcache) {
	delete cpcache.aFrames;
	delete cpcache.aEvents;
	delete cpcache.aOutputWaits;
	delete cpcache.customdata;
}

void Exception_NotImplemented(int client) {
	ThrowError("This feature is not implemented.");
}