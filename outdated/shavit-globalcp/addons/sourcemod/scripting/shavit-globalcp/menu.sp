/* -- Menu -- */
void OpenGlobalCheckpointsMenu(int client, int item = 0) {
	char sInfo[64];

	Menu hMenu = new Menu(MenuHandler_GlobalCheckpoints);
	hMenu.SetTitle("%T", "GCPMenuTitle", client);

	bool bIsFull = (GetMaxCPs(client) <= Shavit_GetTotalCheckpoints(client));
	bool bIsSelected = (gI_CheckpointSelected[client] != 0);

	FormatEx(sInfo, sizeof(sInfo), "%T", "GCPMenuSave", client);

	if (bIsSelected)
		FormatEx(sInfo, sizeof(sInfo), "%s #%d -> #%d", sInfo,
			gI_CheckpointSelected[client],
			Shavit_GetTotalCheckpoints(client) + 1);

	if (bIsFull)
		FormatEx(sInfo, sizeof(sInfo), "%s %T", sInfo, "GCPMenuFull", client);

	hMenu.AddItem("save", sInfo, (bIsFull || !bIsSelected) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	FormatEx(sInfo, sizeof(sInfo), "%T", "GCPMenuRecreate", client);
	hMenu.AddItem("export", sInfo, bIsSelected ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	FormatEx(sInfo, sizeof(sInfo), "%T", "GCPMenuOpenMenu", client);
	hMenu.AddItem("cpmenu", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "%T\n ", "GCPMenuRefresh", client);
	hMenu.AddItem("refresh", sInfo);

	if (gI_CheckpointsSaved == 0) {
		FormatEx(sInfo, sizeof(sInfo), "%T", "GCPMenuNothing", client);
		hMenu.AddItem("", sInfo, ITEMDRAW_DISABLED);
	} else {
		int iIndex;
		char sIndex[8];

		for (iIndex = gI_CheckpointsSaved; iIndex > 0; iIndex--) {
			global_cp_cache_t checkpoint;
			gA_GlobalCheckpoints.GetArray(iIndex-1, checkpoint, sizeof(checkpoint));

			char sStyle[16];
			Shavit_GetStyleSetting(checkpoint.cpcache.aSnapshot.bsStyle, "name", sStyle, sizeof(sStyle));

			char sTimeBuffer[16];
			GetFormatedLapsedTime(client, checkpoint.iSaveTime, GetTime(), sTimeBuffer, sizeof(sTimeBuffer));

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
			SaveGlobalCheckpointForPlayer(param1, gI_CheckpointSelected[param1]);
		} else if (StrEqual(sInfo, "export")) {
			char sSaveInfo[64];

			global_cp_cache_t checkpoint;
			gA_GlobalCheckpoints.GetArray(gI_CheckpointSelected[param1] - 1, checkpoint, sizeof(checkpoint));

			GetCheckpointInfo(checkpoint.cpcache, sSaveInfo, sizeof(sSaveInfo));
			CPrintToChat(param1, "{white}sm_saveloc %s", sSaveInfo);
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

/* -- Static functions -- */
static void GetFormatedLapsedTime(int client, int timestamp, int currentTime, char[] buffer, int size) {
	int iLapsedTime = currentTime - timestamp;

	if (iLapsedTime < 10)
		FormatEx(buffer, size, "%T", "GCPMenuJustNow", client);
	else if (iLapsedTime >= 10 && iLapsedTime < 61)
		FormatEx(buffer, size, "%T", "GCPMenuSecondsAgo", client, iLapsedTime);
	else if (iLapsedTime >= 61 && iLapsedTime < 3601)
		FormatEx(buffer, size, "%T", iLapsedTime / 60 == 1 ? "GCPMenuMinuteAgo" : "GCPMenuMinutesAgo", client, iLapsedTime / 60);
	else
		FormatEx(buffer, size, "%T", "GCPMenuLongLongAgo", client);
}