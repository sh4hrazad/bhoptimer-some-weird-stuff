void OnCheckpointCacheSaved(int client, cp_cache_t cpcache) {
        global_cp_cache_t checkpoint;
	checkpoint.cpcache = cpcache;

	delete checkpoint.cpcache.aFrames;

	if (cpcache.aEvents)
		checkpoint.cpcache.aEvents = cpcache.aEvents.Clone();
	if (cpcache.aOutputWaits)
		checkpoint.cpcache.aOutputWaits = cpcache.aOutputWaits.Clone();
	if (cpcache.customdata)
		checkpoint.cpcache.customdata = view_as<StringMap>(CloneHandle(cpcache.customdata));

	GetClientName(client, checkpoint.sPlayerName, sizeof(checkpoint.sPlayerName));
	checkpoint.iCheckpointNumber = gI_CheckpointsSaved + 1;
	checkpoint.iSaveTime = GetTime();

	gA_GlobalCheckpoints.PushArray(checkpoint);
	gI_CheckpointsSaved++;
}

bool OnTeleportToGlobalCheckpoint(int client, int index) {
	if (Shavit_IsPaused(client)) {
		CPrintToChat(client, "%T", "GCPTimerResume", client);

		return false;
	}

	global_cp_cache_t checkpoint;
	gA_GlobalCheckpoints.GetArray(index - 1, checkpoint, sizeof(global_cp_cache_t));


	if(IsNullVector(checkpoint.cpcache.fPosition)) {
		return false;
	}

	if(Shavit_InsideZone(client, Zone_Start, -1)) {
		Shavit_StopTimer(client);
	}
	
	Shavit_LoadCheckpointCache(client, checkpoint.cpcache, 0, sizeof(cp_cache_t));
	Shavit_SetPracticeMode(client, true, true);
	Shavit_ResumeTimer(client);

	return true;
}

bool OnSaveGlobalCheckpointForPlayer(int client, int index) {
	if (Shavit_IsPaused(client)) {
		CPrintToChat(client, "%T", "GCPTimerResume", client);

		return false;
	} else if (Shavit_GetTotalCheckpoints(client) == GetMaxCPs(client)) {
		CPrintToChat(client, "%T", "GCPFull", client);

		return false;
	}

	global_cp_cache_t checkpoint;
	gA_GlobalCheckpoints.GetArray(index - 1, checkpoint, sizeof(checkpoint));

	Shavit_SetCheckpoint(client, -1, checkpoint.cpcache, sizeof(cp_cache_t), false);
	Shavit_SetCurrentCheckpoint(client, Shavit_GetTotalCheckpoints(client));
	
	return true;
}

int OnSaveLocation(int client, char sSavelocInfo[9][8]) {
	int iStyle = Shavit_GetBhopStyle(client);
	global_cp_cache_t checkpoint;

	for (int i = 0; i < 3; i++) {
		checkpoint.cpcache.fPosition[i] = StringToFloat(sSavelocInfo[i]);
		checkpoint.cpcache.fAngles[i] = StringToFloat(sSavelocInfo[i + 3]);
		checkpoint.cpcache.fVelocity[i] = StringToFloat(sSavelocInfo[i + 6]);
	}
	
	checkpoint.cpcache.iMoveType = MOVETYPE_WALK;
	checkpoint.cpcache.fGravity = Shavit_GetStyleSettingFloat(iStyle, "gravity");
	checkpoint.cpcache.fSpeed = Shavit_GetStyleSettingFloat(iStyle, "timescale") * Shavit_GetStyleSettingFloat(iStyle, "speed");

	ScaleVector(checkpoint.cpcache.fVelocity, 1 / checkpoint.cpcache.fSpeed);

	checkpoint.cpcache.iFlags = GetEntityFlags(client) & ~(FL_ATCONTROLS|FL_FAKECLIENT);

	Shavit_SaveSnapshot(client, checkpoint.cpcache.aSnapshot);
	checkpoint.cpcache.aSnapshot.bTimerEnabled = false;

	Shavit_SetCheckpoint(client, -1, checkpoint.cpcache);
	Shavit_SetCurrentCheckpoint(client, Shavit_GetTotalCheckpoints(client));

	GetClientName(client, checkpoint.sPlayerName, sizeof(checkpoint.sPlayerName));
	checkpoint.iCheckpointNumber = gI_CheckpointsSaved + 1;
	checkpoint.iSaveTime = GetTime();

	gA_GlobalCheckpoints.PushArray(checkpoint);
	gI_CheckpointsSaved++;

	return Shavit_GetTotalCheckpoints(client);
}