#include <sourcemod>

public Plugin myinfo = {
	name = "Hitokoto: Source",
	author = "Shahrazad",
	description = "Grab proverbs or sentences from Hitokoto's API for players and server's hostname"
}

#include <json>
#include <steamworks>

#include <convar_class>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define HITOKOTO_API "https://v1.hitokoto.cn/"
#define HITOKOTO_PLAYER_REF ""
#define HITOKOTO_HOSTNAME_REF "?max_length=10&c=i"
#define FOR_HOSTNAME -1

ConVar gCV_Hostname = null;

enum struct HitokotoInfo {
	int id;
	char hitokoto[512];	// Sentence content
	char type[4];		// Sentence type
	char from[32];
	char from_who[32];		
	char creator[32];
	char date[16];
}

HitokotoInfo g_Hitokoto;

public void OnPluginStart() {
	gCV_Hostname = FindConVar("hostname");

	RegConsoleCmd("sm_hitokoto", Command_Hitokoto, "Print a sentence in the chat box.");
}

public void OnMapStart() {
	GetSentence(FOR_HOSTNAME);
}

public Action Command_Hitokoto(int client, int args) {
	if (IsValidClient(client)) {
		GetSentence(GetClientSerial(client));
	}
}

public void OnClientPutInServer(int client) {
	if (IsValidClient(client)) {
		GetSentence(GetClientSerial(client));
	}
}

bool IsValidClient(int client) {
	return (0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client);
}

void GetSentence(int serial) {
	char sApiUrl[256];
	StrCat(sApiUrl, sizeof(sApiUrl), HITOKOTO_API);

	if (serial != FOR_HOSTNAME) {
		StrCat(sApiUrl, sizeof(sApiUrl), HITOKOTO_PLAYER_REF);
	} else {
		StrCat(sApiUrl, sizeof(sApiUrl), HITOKOTO_HOSTNAME_REF);
	}

	DataPack dp = new DataPack();
	dp.WriteCell(serial);

	Handle hRequest;
	if (!(hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sApiUrl))
	 || !SteamWorks_SetHTTPRequestHeaderValue(hRequest, "accept", "application/json")
	 || !SteamWorks_SetHTTPRequestContextValue(hRequest, dp)
	 || !SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(hRequest, 4000)
	 || !SteamWorks_SetHTTPCallbacks(hRequest, RequestCompletedCallback)
	 || !SteamWorks_SendHTTPRequest(hRequest)) {
		CloseHandle(dp);
		CloseHandle(hRequest);
		PrintToServer("Hitokoto: failed to setup & send HTTP request");
		return;
	}
}

public void RequestCompletedCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, DataPack dataPack) {
	dataPack.Reset();
	PrintToServer("bFailure = %d, bRequestSuccessful = %d, eStatusCode = %d", failure, requestSuccessful, statusCode);

	if (failure || !requestSuccessful || statusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("Hitokoto: API request failed");

		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(request, ResponseBodyCallback, dataPack);
}

void ResponseBodyCallback(const char[] data, DataPack dataPack, int dataLen) {
	dataPack.Reset();
	int client = dataPack.ReadCell();
	if (client != FOR_HOSTNAME) {
		client = GetClientFromSerial(client);
	}
	CloseHandle(dataPack);

	if (client == 0) {
		return; // invalid client
	}

	JSON_Object json_Sentence = json_decode(data);

	g_Hitokoto.id = json_Sentence.GetInt("id");
	json_Sentence.GetString("hitokoto", g_Hitokoto.hitokoto, sizeof(g_Hitokoto.hitokoto));
	json_Sentence.GetString("type", g_Hitokoto.type, sizeof(g_Hitokoto.type));

	if (!json_Sentence.GetString("from", g_Hitokoto.from, sizeof(g_Hitokoto.from)))
		g_Hitokoto.from = "";
	if (!json_Sentence.GetString("from_who", g_Hitokoto.from_who, sizeof(g_Hitokoto.from_who)))
		g_Hitokoto.from_who = "";
	if (!json_Sentence.GetString("creator", g_Hitokoto.creator, sizeof(g_Hitokoto.creator)))
		g_Hitokoto.creator = "";

	json_Sentence.GetString("date", g_Hitokoto.date, sizeof(g_Hitokoto.date));

	delete json_Sentence;

	if (client != FOR_HOSTNAME) {
		// 『*句子』
		// 		—— 作者『出处』
		CPrintToChat(client, "{white}『 {lightgreen}%s {white}』", g_Hitokoto.hitokoto);
		CPrintToChat(client, "                                     {white}—— {lightgreen}%s{white}「{lightgreen}%s{white}」", g_Hitokoto.from_who, g_Hitokoto.from);
	} else {
		char sHostname[64];
		GetConVarString(gCV_Hostname, sHostname, sizeof(sHostname));

		FormatEx(sHostname, sizeof(sHostname), "%s 「%s」", sHostname, g_Hitokoto.hitokoto);
		SetConVarString(gCV_Hostname, sHostname);
	}
}
