#include <sourcemod>
#include <fuckZones>
#include <multicolors>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

bool gB_NoJump[MAXPLAYERS + 1];

int gI_LastButtons[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[fuckZones] No Jump Zone",
	author = "Shahrazad"
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (buttons & IN_JUMP && gB_NoJump[client]) {
		if (!(gI_LastButtons[client] & IN_JUMP))
			CPrintToChat(client, "{white}You may {red}not{white} jump in this area.");
	}

	gI_LastButtons[client] = buttons;

	if (buttons & IN_JUMP && gB_NoJump[client])
		buttons &= ~IN_JUMP;

	return Plugin_Continue;
}

public void fuckZones_OnTouchZone_Post(int client, int entity, const char[] zone_name, int type) {
	if (StrContains(zone_name, "nojump", false) != -1) {
		gB_NoJump[client] = true;
	}
}

public void fuckZones_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type) {
	if (StrContains(zone_name, "nojump", false) != -1) {
		gB_NoJump[client] = false;
	}
}