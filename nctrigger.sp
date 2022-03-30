#include <sourcemod>
#include <sdkhooks>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

bool gB_CanTouchTrigger[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Noclip trigger toggle",
	author = "not Shahrazad"
}

public void OnPluginStart() {
	RegConsoleCmd("sm_nctrigger", Command_NoclipIgnoreTrigger, "Toggle noclip triggers.");
	RegConsoleCmd("sm_nctriggers", Command_NoclipIgnoreTrigger, "Toggle noclip triggers.");
}

public void OnClientPutInServer(int client) {
	gB_CanTouchTrigger[client] = true;
}

public Action Command_NoclipIgnoreTrigger(int client, int args) {
	if (client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}

	gB_CanTouchTrigger[client] = !gB_CanTouchTrigger[client];
	CPrintToChat(client, "{white}Noclip trigger {lightgreen}%s{white}.", gB_CanTouchTrigger[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "trigger_apply_impulse")
	|| StrEqual(classname, "trigger_capture_area")
	|| StrEqual(classname, "trigger_catapult")
	|| StrEqual(classname, "trigger_hurt")
	|| StrEqual(classname, "trigger_impact")
	|| StrEqual(classname, "trigger_teleport_relative")
	|| StrEqual(classname, "trigger_multiple")
	|| StrEqual(classname, "trigger_once")
	|| StrEqual(classname, "trigger_push")
	|| StrEqual(classname, "trigger_teleport") 
	|| StrEqual(classname, "trigger_gravity")) {
		SDKHook(entity, SDKHook_StartTouch, HookTrigger);
		SDKHook(entity, SDKHook_EndTouch, HookTrigger);
		SDKHook(entity, SDKHook_Touch, HookTrigger);
	}
}

public Action HookTrigger(int entity, int other) {
	if (IsValidClient(other)) {
		if (!gB_CanTouchTrigger[other] && GetEntityMoveType(other) & MOVETYPE_NOCLIP)
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsValidClient(int client) {
	return client >= 1 
		&& client <= MaxClients 
		&& IsClientConnected(client) 
		&& IsClientInGame(client) 
		&& !IsClientSourceTV(client);
}
