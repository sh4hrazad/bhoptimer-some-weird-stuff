#include <sourcemod>

#include <json>
#include <steamworks>

#include <convar_class>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

Convar gCV_HitokotoAPIUrl = null;

enum struct HitokotoInfo {
	int id;
	char hitokoto[512];	// Sentence content
	char type[1];		// Sentence type
	char from[32];
	char from_who[32];		
	char creator[32];
	char date[16];
}

HitokotoInfo g_Hitokoto;

public Plugin myinfo = {
	name = "Hitokoto: Source",
	author = "Shahrazad",
	description = "Grab proverbs or sentences from Hitokoto's API"
}

public void OnPluginStart() {
	gCV_HitokotoAPIUrl = new Convar("hitokoto_api_url", "https://v1.hitokoto.cn/", "Url of Hitokoto's API\nRead https://developer.hitokoto.cn/sentence/ for usage.\nShould leave it as default usually.", FCVAR_PROTECTED);

	Convar.AutoExecConfig();

	RegConsoleCmd("sm_hitokoto", Command_Hitokoto, "Print a sentence in the chat box.");
}

Action Command_Hitokoto(int client, int args) {
	if (IsValidClient(client)) {
		GetSentence(client);
	}
}

public void OnClientPutInServer(int client) {
	if (IsValidClient(client)) {
		GetSentence(client);
	}
}

bool IsValidClient(int client, bool botsValid = false) {
	return (0 < client <= MaxClients) && IsClientInGame(client) && (botsValid || !IsFakeClient(client));
}

void GetSentence(int client) {
	int iSerial = GetClientSerial(client);
	char sApiUrl[256];

	if (!gCV_HitokotoAPIUrl.GetString(sApiUrl, sizeof(sApiUrl))) {
		PrintToServer("Hitokoto: API Url is not set.");

		return;
	}

	DataPack dp = new DataPack();
	dp.WriteCell(iSerial);

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
	int client = GetClientFromSerial(dataPack.ReadCell());
	CloseHandle(dataPack);

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

	// 『*句子』
	// 		—— 作者『出处』
	CPrintToChat(client, "{white}『 {lightgreen}%s {white}』", g_Hitokoto.hitokoto);
	CPrintToChat(client, "                                     {white}—— {lightgreen}%s{white}「{lightgreen}%s{white}」", g_Hitokoto.from_who, g_Hitokoto.from);
}
