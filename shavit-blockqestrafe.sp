#include <sourcemod>
#include <shavit/core>
#include <shavit/zones>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
	name = "[Shavit] Q/E strafe detector",
	author = "Shahrazad",
	description = "stop a player's timer who strafes using Q/E"
};

float gF_DetectionTime = 1.5;

enum struct QEInfo {
	float fLastTime;
	int iLastButtons;
	int iQECount;
}

QEInfo g_QEInfo[MAXPLAYERS + 1];

public void OnPluginStart() {
	// do nothing maybe
}

public void OnClientPutInServer(int client)
{
	g_QEInfo[client].fLastTime = 0.0;
	g_QEInfo[client].iLastButtons = 0;
	g_QEInfo[client].iQECount = 0;
}

public void OnClientDisconnect_Post(int client) {
	g_QEInfo[client].iLastButtons = 0;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, int mouse[2]) {
	if((Shavit_GetStyleSettingBool(style, "block_pleft")
	&& Shavit_GetStyleSettingBool(style, "block_pright")) // detect only when +left/+right not restricted based on timer
	|| Shavit_GetClientTime(client) == 0.0 // dont detect in start zone (if timer not running)
	|| Shavit_GetStyleSettingBool(style, "tas") /* dont check tas style */) {
		g_QEInfo[client].iQECount = 0;

		return Plugin_Continue;
	}
    
	if (buttons & IN_LEFT) {
		if (!(g_QEInfo[client].iLastButtons & IN_LEFT))
			OnButtonPress(client, IN_LEFT);
	} else if (buttons & IN_RIGHT) {
		if (!(g_QEInfo[client].iLastButtons & IN_RIGHT))
			OnButtonPress(client, IN_RIGHT);
	}

	g_QEInfo[client].iLastButtons = buttons;

	return Plugin_Continue;
}

public void OnButtonPress(int client, int button) {
	float curTime = GetGameTime();
	float newTime = curTime + gF_DetectionTime;

	if (g_QEInfo[client].fLastTime >= curTime) {
		if (g_QEInfo[client].iQECount < 5) {
			g_QEInfo[client].iQECount++;
			CPrintToChat(client, "{white}%s detected. (%s%i{white}/{lightgreen}%i{white})",
			button == IN_LEFT ? "+left" : "+right",
			g_QEInfo[client].iQECount == 5 ? "{red}" : "{lightblue}",
			g_QEInfo[client].iQECount, 5);
			if (g_QEInfo[client].iQECount == 5) {
				CPrintToChat(client, "{red}!!! {white}USING {lightgreen}+left{white}/{lightgreen}+right{white} TOO FREQUENTLY WILL RESULT IN TIMER STOPPED {red}!!!");
			}
		} else {
			QEStopTimer(client);
		}
	} else if (g_QEInfo[client].iQECount > 1) {
		g_QEInfo[client].iQECount--;
		CPrintToChat(client, "{white}%s detected. ({lightblue}%i{white}/{lightgreen}%i{white})",
		button == IN_LEFT ? "+left" : "+right",
		g_QEInfo[client].iQECount, 5);
	} else if (g_QEInfo[client].iQECount == 0) {
		g_QEInfo[client].iQECount++; // initialize
		CPrintToChat(client, "{white}%s detected. ({lightblue}%i{white}/{lightgreen}%i{white})",
		button == IN_LEFT ? "+left" : "+right", g_QEInfo[client].iQECount, 5);
	}

	g_QEInfo[client].fLastTime = newTime;
}

public void QEStopTimer(int client) {
	Shavit_StopTimer(client);
	CPrintToChat(client, "{white}i said {red}:(");
	g_QEInfo[client].iQECount = 0;
}
