/**
 * A lite version of zspeed.sp
 */

#include <sourcemod>
#include <multicolors>
#include <clientprefs>
#include <DynamicChannels>

#define TICKS_PER_UPDATE 5

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
	name = "Show Speed",
	author = "Shahrazad"
}

Handle gH_SpeedHUD = null;
Handle gH_ShowSpeedCookie;
bool gB_ShowSpeed[MAXPLAYERS + 1] = {true, ...};

public void OnPluginStart() {
	gH_SpeedHUD = CreateHudSynchronizer();

	RegConsoleCmd("sm_showspeed", Command_ShowSpeed, "toggles show speed (bigger text).");
	gH_ShowSpeedCookie = RegClientCookie("showspeed_enabled", "showspeed_enabled", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++) {
		if (AreClientCookiesCached(i)) OnClientCookiesCached(i);
	}
}

public void OnClientCookiesCached(int client) {
	gB_ShowSpeed[client] = GetClientCookieBool(client, gH_ShowSpeedCookie);
}

public Action Command_ShowSpeed(int client, int args) {
	if (client != 0) {
		gB_ShowSpeed[client] = !gB_ShowSpeed[client];
		SetClientCookieBool(client, gH_ShowSpeedCookie, gB_ShowSpeed[client]);
		
		CReplyToCommand(client, "{white}Showspeed {lightgreen}%s{white}.", gB_ShowSpeed[client] ? "enabled" : "disabled");
	} else {
		ReplyToCommand(client, "[SM] Invalid client!");
	}
	
	return Plugin_Handled;
}

public void OnPlayerRunCmd(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {
	if (!gB_ShowSpeed[client] || !((0 < client <= MaxClients) && IsClientInGame(client)))
		return;

	if((GetGameTickCount() % TICKS_PER_UPDATE) == 0) {
		int target = GetSpectatorTarget(client);

		float fSpeed[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", fSpeed);

		float fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));

		char sBuffer[64];
	
		SetHudTextParams(-1.0, 0.55, 0.5, 0, 255, 255, 255, 0, 1.0, 0.0, 0.0);
		Format(sBuffer, sizeof(sBuffer), "%d", RoundToFloor(fCurrentSpeed));

		ShowHudText(client, GetDynamicChannel(0), "%s", sBuffer);
		// ShowSyncHudText(client, gH_SpeedHUD, "%s", sBuffer);
	}
}

int GetSpectatorTarget(int client) {
	if (IsClientObserver(client)) {
		int mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if (mode == 4 || mode == 5) { // 4 = ineye mode, 5 = chase mode
			int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (target != -1) return target;
		}
	}

	return client;
}

bool GetClientCookieBool(int client, Handle cookie)
{
	char sValue[8];
	GetClientCookie(client, cookie, sValue, sizeof(sValue));

	return (sValue[0] != '\0' && StringToInt(sValue));
}

void SetClientCookieBool(int client, Handle cookie, bool value)
{
	char sValue[8];
	IntToString(value, sValue, sizeof(sValue));

	SetClientCookie(client, cookie, sValue);
}
