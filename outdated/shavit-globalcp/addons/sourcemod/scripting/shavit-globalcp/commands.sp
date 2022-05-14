void RegisterCommand() {
	RegConsoleCmd("sm_gcp", Command_GlobalCheckpoints,
		"Show a menu that lists checkpoints that all players saved.");
	RegConsoleCmd("sm_getcp", Command_GetCheckpoint,
		"Copy a checkpoint to your menu from global cps menu. Usage: sm_getcp <global cp num>");
	RegConsoleCmd("sm_saveloc", Command_Saveloc,
		"Make a checkpoint. Usage: sm_saveloc [posX|posY|posZ|angleX|angleY|angleZ|velX|velY|velZ]");
}

/* -- Commands -- */
public Action Command_GlobalCheckpoints(int client, any args) {
	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");

		return Plugin_Handled;
	} else if (!gCV_Checkpoints.BoolValue) {
		CPrintToChat(client, "%T", "GCPFeatureDisabled", client);

		return Plugin_Handled;
	}

	OpenGlobalCheckpointsMenu(client);

	return Plugin_Handled;
}

public Action Command_GetCheckpoint(int client, any args) {
	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");

		return Plugin_Handled;
	} else if (!gCV_Checkpoints.BoolValue) {
		CPrintToChat(client, "%T", "GCPFeatureDisabled", client);

		return Plugin_Handled;
	} else if (args < 1) {
		CPrintToChat(client, "{white}Usage: sm_getcp <{lightgreen}global cp num{white}>");

		return Plugin_Handled;
	}

	char sArg[5];
	GetCmdArg(1, sArg, sizeof(sArg));
	int iCPNumber = StringToInt(sArg);

	if (!iCPNumber || iCPNumber > gA_GlobalCheckpoints.Length) {
		CPrintToChat(client, "%T", "GCPNotFound", client, iCPNumber);
		return Plugin_Handled;
	}

	bool iIsSaved = SaveGlobalCheckpointForPlayer(client, iCPNumber);

	if (iIsSaved) {
		// find the destination that saved the checkpoint
		int iMaxCPs = GetMaxCPs(client);
		bool bOverflow = (Shavit_GetTotalCheckpoints(client) >= iMaxCPs);
		int iSaveIndex = bOverflow ? iMaxCPs : Shavit_GetTotalCheckpoints(client);

		CPrintToChat(client, "%T", "GCPCopied", client,
			iCPNumber, iSaveIndex);
	}

	return Plugin_Handled;
}

public Action Command_Saveloc(int client, any args) {
	bool bKZ = Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "kzcheckpoints");

	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");

		return Plugin_Handled;
	} else if (!gCV_Checkpoints.BoolValue) {
		CPrintToChat(client, "%T", "GCPFeatureDisabled", client);

		return Plugin_Handled;
	} else if(Shavit_IsPaused(client)) {
		CPrintToChat(client, "%T", "GCPTimerResume", client);

		return Plugin_Handled;
	} else if (Shavit_GetTotalCheckpoints(client) == GetMaxCPs(client)) {
		CPrintToChat(client, "%T", "GCPFull", client);

		return Plugin_Handled;
	} else if (args < 1) {
		int iIndex = Shavit_SaveCheckpoint(client);
		if (iIndex) {
			cp_cache_t cpcache;
			Shavit_GetCheckpoint(client, iIndex, cpcache);

			char sSaveInfo[64];
			GetCheckpointInfo(cpcache, sSaveInfo, sizeof(sSaveInfo));

			CPrintToChat(client, "%T", "GCPSaved", client, Shavit_GetCurrentCheckpoint(client));

			if (!bKZ)
				CPrintToChat(client, "%T", "GCPRecreate", client, sSaveInfo);
		}
		return Plugin_Handled;
	} else if (bKZ) {
		CPrintToChat(client, "%T", "GCPBlockKZ", client);

		return Plugin_Handled;
	}

	char sArg[64];
	GetCmdArg(1, sArg, sizeof(sArg));

	char sSavelocInfo[9][8];
	if (ExplodeString(sArg, "|", sSavelocInfo, 9, 8) != 9) {
		CPrintToChat(client, "%T", "GCPInvalid", client);

		return Plugin_Handled;
	}

	if (SaveLocation(client, sSavelocInfo)) {
		CPrintToChat(client, "%T", "GCPSaved", client, Shavit_GetCurrentCheckpoint(client));
		CPrintToChat(client, "%T", "GCPRecreate", client, sArg);
	}

	return Plugin_Handled;
}