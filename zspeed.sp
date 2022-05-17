#include <sourcemod>

public Plugin myinfo = {
	name = "zSpeed",
	author = "Shahrazad"
}

/* ---------- TOO LAZY TO ADD CONVARS FOR THEM ---------- */

/**
 * HUD 刷新率 (recommended: 5/3 (100/66 tick))
 * 注意不要设置得太低, 否则会卡.
 */
#define TICKS_PER_UPDATE 5

/**
 * HUD 单次刷新后持续时间 (default: 0.1)
 * 如果服务器 HudText 占用多, 容易导致冲突, 可尝试调低些, 太低 HUD 会闪烁.
 * 如果是 66/64 tick, 建议持续时间不要低于 0.5s.
 */
#define HUD_HOLD_TIME 0.1

/**
 * 动态 HUD 显示颜色 (default: {0, 180, 255}, {255, 90, 0})
 * 动态 HUD 功能关闭时将使用 COLOR_INC 所设置的颜色.
 */
#define COLOR_INC 	{0, 180, 255}
#define COLOR_DEC 	{255, 90, 0}

/* ------------------------------------------------------ */

#include <multicolors>
#include <clientprefs>
#include <shavit/core>
#include <shavit/hud>
#include <shavit/replay-playback>
#include <DynamicChannels>

#define POSITION_CENTER -1.0
#define HUD_BUF_SIZE 64

#pragma newdecls required
#pragma semicolon 1

enum CookieType {
	CT_Integer = 0,
	CT_Boolean,
	CT_Float
};

enum {
	AXIS_X = 0,
	AXIS_Y
};

enum struct SpeedCookies {
	Cookie showSpeed;
	Cookie positionX;
	Cookie positionY;
	Cookie dynamic;
	Cookie speedDiff;
	Cookie freshman;
}

enum struct SpeedSettings {
	bool showSpeed;
	float position[2];
	bool dynamic;
	bool speedDiff;
}

SpeedCookies Cookies;
SpeedSettings Settings[MAXPLAYERS + 1];

bool gB_SettingAxis[MAXPLAYERS + 1];
float gF_Modifier[MAXPLAYERS + 1];

float gF_LastSpeed[MAXPLAYERS + 1];

public void OnPluginStart() {
	RegConsoleCmd("sm_showspeed", Command_ShowSpeed, "Toggles zSpeed HUD.");
	RegConsoleCmd("sm_zspeed", Command_ZSpeedMenu, "Opens zSpeed settings menu.");

	Cookies.showSpeed = new Cookie("showspeed_enabled", "[zSpeed] Main", CookieAccess_Protected);
	Cookies.positionX = new Cookie("showspeed_positionx", "[zSpeed] Position (x)", CookieAccess_Protected);
	Cookies.positionY = new Cookie("showspeed_positiony", "[zSpeed] Position (y)", CookieAccess_Protected);
	Cookies.dynamic   = new Cookie("showspeed_dynamic", "[zSpeed] Dynamic Colors", CookieAccess_Protected);
	Cookies.speedDiff = new Cookie("showspeed_difference", "[zSpeed] Speed Difference", CookieAccess_Protected);
	Cookies.freshman  = new Cookie("showspeed_freshman", "[zSpeed] Freshman", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++) {
		if (AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		} 
	}
}

public void OnClientPutInServer(int client) {
	gF_Modifier[client] = 0.1;
}

/* -- Cookies -- */

public void OnClientCookiesCached(int client) {
	if(!GetCookie(client, Cookies.freshman, CT_Boolean)) {
		SetCookie(client, Cookies.showSpeed, CT_Boolean, true);
		SetCookie(client, Cookies.positionX, CT_Float,   POSITION_CENTER);
		SetCookie(client, Cookies.positionY, CT_Float,   0.55);
		SetCookie(client, Cookies.dynamic,   CT_Boolean, true);
		SetCookie(client, Cookies.speedDiff, CT_Boolean, true);
		SetCookie(client, Cookies.freshman,  CT_Boolean, true);
	}

	Settings[client].showSpeed   = GetCookie(client, Cookies.showSpeed, CT_Boolean);
	Settings[client].position[0] = GetCookie(client, Cookies.positionX, CT_Float);
	Settings[client].position[1] = GetCookie(client, Cookies.positionY, CT_Float);
	Settings[client].dynamic     = GetCookie(client, Cookies.dynamic,   CT_Boolean);
	Settings[client].speedDiff   = GetCookie(client, Cookies.speedDiff, CT_Boolean);
}

void SetCookie(int client, Cookie cookie, CookieType type, any value) {
	char sValue[8];

	switch (type) {
		case CT_Integer, CT_Boolean: {
			IntToString(view_as<int>(value), sValue, sizeof(sValue));
		}
		case CT_Float: {
			FloatToString(view_as<float>(value), sValue, sizeof(sValue));
		}
	}
	
	cookie.Set(client, sValue);
}

any GetCookie(int client, Cookie cookie, CookieType type) {
	char sValue[8];

	cookie.Get(client, sValue, sizeof(sValue));

	switch (type) {
		case CT_Integer, CT_Boolean: {
			return StringToInt(sValue);
		}
		case CT_Float: {
			return StringToFloat(sValue);
		}
	}

	return -1;
}

void OnCookieChanged(int client) {
	SetCookie(client, Cookies.showSpeed, CT_Boolean, Settings[client].showSpeed);
	SetCookie(client, Cookies.positionX, CT_Float,   Settings[client].position[AXIS_X]);
	SetCookie(client, Cookies.positionY, CT_Float,   Settings[client].position[AXIS_Y]);
	SetCookie(client, Cookies.dynamic,   CT_Boolean, Settings[client].dynamic);
	SetCookie(client, Cookies.speedDiff, CT_Boolean, Settings[client].speedDiff);
}

/* -- Commands -- */

public Action Command_ShowSpeed(int client, int args) {
	if (client == 0) { return Plugin_Handled; }

	Settings[client].showSpeed = !Settings[client].showSpeed;
	OnCookieChanged(client);
		
	CPrintToChat(
		client, "{white}Showspeed %s{white}.",
		Settings[client].showSpeed ? "{lightgreen}enabled" : "{red}disabled"
	);
	
	return Plugin_Handled;
}

public Action Command_ZSpeedMenu(int client, int args) {
	if (client == 0) { return Plugin_Handled; }

	OpenZSpeedMenu(client);

	return Plugin_Handled;
}

/* -- Menus -- */

void OpenZSpeedMenu(int client, int item = 0) {
	Menu hMenu = new Menu(ZSpeedMenu_Handler);
	hMenu.SetTitle("zSpeed Settings");

	char sInfo[32];

	FormatEx(sInfo, sizeof(sInfo), "[%s] Master", Settings[client].showSpeed ? "√" : " ");
	hMenu.AddItem("master", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Position\nCurrent: %.3f, %.3f", Settings[client].position[0], Settings[client].position[1]);
	hMenu.AddItem("position", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "[%s] Dynamic Color", Settings[client].dynamic ? "√" : " ");
	hMenu.AddItem("dynamic", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "[%s] Speed Difference", Settings[client].speedDiff ? "√" : " ");
	hMenu.AddItem("difference", sInfo);

	hMenu.ExitButton = true;
	hMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int ZSpeedMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if (StrEqual(sInfo, "master")) {
			Settings[param1].showSpeed = !Settings[param1].showSpeed;
		} else if (StrEqual(sInfo, "position")) {
			OpenPositionSettingsMenu(param1);

			return 0;
		} else if (StrEqual(sInfo, "dynamic")) {
			Settings[param1].dynamic = !Settings[param1].dynamic;
		} else if (StrEqual(sInfo, "difference")) {
			Settings[param1].speedDiff = !Settings[param1].speedDiff;
		}

		OnCookieChanged(param1);
		OpenZSpeedMenu(param1, GetMenuSelectionPosition());
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void OpenPositionSettingsMenu(int client) {
	Menu hMenu = new Menu(PositionSettingsMenu_Handler);
	hMenu.SetTitle(
		"Position Settings\nCurrent Position: (%.3f, %.3f)\n ",
		Settings[client].position[0], Settings[client].position[1]
	);

	char sInfo[33];

	FormatEx(sInfo, sizeof(sInfo), "Axis: %s", gB_SettingAxis[client] ? "X" : "Y");
	hMenu.AddItem("axis", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Modifier: %d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("modifier", sInfo);

	hMenu.AddItem("center", "Center\n ");

	FormatEx(sInfo, sizeof(sInfo), "+%d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("+", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "-%d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("-", sInfo);

	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

int PositionSettingsMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int iAxis = gB_SettingAxis[param1] ? AXIS_X : AXIS_Y;

		if (StrEqual(sInfo, "axis"))          { gB_SettingAxis[param1] = !gB_SettingAxis[param1]; }
		else if (StrEqual(sInfo, "modifier")) { gF_Modifier[param1] = gF_Modifier[param1] == 0.1 ? 0.01 : gF_Modifier[param1] == 0.01 ? 0.001 : 0.1; }
		else if (StrEqual(sInfo, "center"))   { Settings[param1].position[iAxis] = POSITION_CENTER; }
		else if (StrEqual(sInfo, "+"))        { AddOrMinusPosition(param1, iAxis, gF_Modifier[param1], true); }
		else if (StrEqual(sInfo, "-"))        { AddOrMinusPosition(param1, iAxis, gF_Modifier[param1], false); }

		OpenPositionSettingsMenu(param1);
	} else if (action == MenuAction_Cancel) {
		OpenZSpeedMenu(param1);
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

/* -- HUD -- */

public Action OnPlayerRunCmd(
	int client, int &buttons, int &impulse,
	float vel[3], float angles[3],
	int &weapon, int &subtype, int &cmdnum,
	int &tickcount, int &seed, int mouse[2]
) {
	if (
		!Settings[client].showSpeed
		 || !IsValidClient(client)
		 || IsFakeClient(client)
		 || GetGameTickCount() % TICKS_PER_UPDATE != 0
	) {
		return;
	}

	int iTarget = GetSpectatorTarget(client, client);

	float fSpeed[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", fSpeed);

	bool bTrueVel = !view_as<bool>(Shavit_GetHUDSettings(client) & HUD_2DVEL);

	char sBuffer[HUD_BUF_SIZE];

	/* -- Speed -- */
	DrawMainSpeedHUD(client, fSpeed, sBuffer, bTrueVel);

	/* -- Difference -- */
	if (
		Settings[client].speedDiff
		 && Shavit_GetClientTime(client) != 0.0
		 && Shavit_GetClosestReplayTime(client) != -1.0
	) {
		DrawSpeedDiffHUD(client, sBuffer, bTrueVel);
	}
}

void DrawMainSpeedHUD(int client, float vel[3], char[] buffer, bool trueVel) {
	float fCurrentSpeed = trueVel ? GetVectorLength(vel) : SquareRoot(Pow(vel[0], 2.0) + Pow(vel[1], 2.0));
	int iColor[3] = COLOR_INC;

	if (Settings[client].dynamic && gF_LastSpeed[client] > fCurrentSpeed) { iColor = COLOR_DEC; }

	SetHudTextParams(
		Settings[client].position[AXIS_X], Settings[client].position[AXIS_Y],
		HUD_HOLD_TIME, iColor[0], iColor[1], iColor[2], 255, 0, 1.0, 0.0, 0.0
	);
	Format(buffer, HUD_BUF_SIZE, "%d", RoundToFloor(fCurrentSpeed));
	ShowHudText(client, GetDynamicChannel(0), "%s", buffer);

	gF_LastSpeed[client] = fCurrentSpeed;
}

void DrawSpeedDiffHUD(int client, char[] buffer, bool trueVel) {
	float fDiff = Shavit_GetClosestReplayVelocityDifference(client, trueVel);
	int iColor[3];

	if (fDiff >= 0.0) {
		iColor = COLOR_INC;
	} else {
		iColor = COLOR_DEC;
	}

	SetHudTextParams(
		Settings[client].position[AXIS_X],
		Settings[client].position[AXIS_Y] == POSITION_CENTER ? 0.52 : Settings[client].position[AXIS_Y] + 0.03,
		HUD_HOLD_TIME, iColor[0], iColor[1], iColor[2], 255, 0, 1.0, 0.0, 0.0
	);
	Format(buffer, HUD_BUF_SIZE, "%d", RoundToFloor(fDiff));
	ShowHudText(client, GetDynamicChannel(1), "(%s%s)", (fDiff >= 0.0) ? "+" : "", buffer);
}

/* -- Helper -- */

void AddOrMinusPosition(int client, int axis, float value, bool add) {
	if (Settings[client].position[axis] == POSITION_CENTER) {
		Settings[client].position[axis] = add ? 0.49 : 0.50;
		SetCookie(client, Cookies.positionX, CT_Float, Settings[client].position[axis]);

		return;
	}

	Settings[client].position[axis] += add ? value : -value;

	if (add ? Settings[client].position[axis] > 1.0 : Settings[client].position[axis] < 0.0) {
		Settings[client].position[axis] = add ? 1.0 : 0.0;
	}

	SetCookie(client, axis == AXIS_X ? Cookies.positionX : Cookies.positionY, CT_Float, Settings[client].position[axis]);
}