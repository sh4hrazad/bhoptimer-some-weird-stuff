void GetCvar() {
        gCV_Checkpoints = FindConVar("shavit_checkpoints_enabled");
	gCV_MaxCP = FindConVar("shavit_checkpoints_maxcp");
	gCV_MaxCP_Segmented = FindConVar("shavit_checkpoints_maxcp_seg");
}

void InitList(bool firstLoad = false) {
        gA_GlobalCheckpoints = new ArrayList(sizeof(global_cp_cache_t));

        if (firstLoad)
                return;

        gI_CheckpointsSaved = 0;

        for(int i = 1; i <= MaxClients; i++) {
                gI_CheckpointSelected[i] = 0;
        }
}

/* -- Miscellaneous code -- */
int GetMaxCPs(int client) {
	return Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "segments") ?
		gCV_MaxCP_Segmented.IntValue : gCV_MaxCP.IntValue;
}

void GetCheckpointInfo(cp_cache_t cpcache, char[] saveInfo, int size) {
	char sSaveInfo[9][8];

	for (int i = 0; i < 3; i++) {
		IntToString(RoundToZero(cpcache.fPosition[i]), sSaveInfo[i], 8);
		IntToString(RoundToZero(cpcache.fAngles[i]), sSaveInfo[i + 3], 8);
		IntToString(RoundToZero(cpcache.fVelocity[i]), sSaveInfo[i + 6], 8);
	}

	ImplodeStrings(sSaveInfo, 9, "|", saveInfo, size);
}
