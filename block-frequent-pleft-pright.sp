#include <sourcemod>

public Plugin myinfo = {
	name = "Block frequent +left/+right",
	author = "Shahrazad"
}

#include <shavit/core>
#include <shavit/checkpoints>
#include <multicolors>

// 侦测等待时间
#define DETECT_TIME 1.5

// 停止计时需要连续按的次数
#define STOPTIMER_TIMES 5

enum struct pInfo {
	int iCount;
	int iLastButtons;
	float fLastTime;
}

pInfo g_pInfo[MAXPLAYERS + 1];

public void OnClientPutInServer(int client) {
	CleanUp(client);
}

public void OnClientDisconnect_Post(int client) {
	CleanUp(client);
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual) {
	CleanUp(client);
}

public Action Shavit_OnStart(int client, int track) {
	CleanUp(client);
}

void CleanUp(int client) {
	g_pInfo[client].iCount = 0;
	g_pInfo[client].iLastButtons = 0;
	g_pInfo[client].fLastTime = 0.0;
}

/**
 * 因为原 timer 使用此功能会报错, 所以注释掉了
 * 解决方法: 在 shavit-checkpoints.sp 中以下两个函数前加 public 关键字后重新编译
 * public void SaveCheckpointCache(int saver, int target, cp_cache_t cpcache, int index, Handle plugin)
 * public bool LoadCheckpointCache(int client, cp_cache_t cpcache, int index, bool force)
 *
 * L 05/17/2022 - 22:47:16: [SM] Exception reported: Invalid Handle 0 (error 4)
 * L 05/17/2022 - 22:47:16: [SM] Blaming: block-frequent-pleft-pright.smx
 * L 05/17/2022 - 22:47:16: [SM] Call stack trace:
 * L 05/17/2022 - 22:47:16: [SM]   [0] StringMap.GetArray
 * L 05/17/2022 - 22:47:16: [SM]   [1] Line 54, .\block-frequent-pleft-pright.sp::Shavit_OnCheckpointCacheLoaded
 * L 05/17/2022 - 22:47:16: [SM]   [3] Call_Finish
 * L 05/17/2022 - 22:47:16: [SM]   [4] Line 1980, .\shavit-checkpoints.sp::LoadCheckpointCache
 * L 05/17/2022 - 22:47:16: [SM]   [5] Line 1836, .\shavit-checkpoints.sp::TeleportToCheckpoint
 * L 05/17/2022 - 22:47:16: [SM]   [6] Line 1219, .\shavit-checkpoints.sp::MenuHandler_Checkpoints
 */

// 存点中保留 +left/+right 次数
public void Shavit_OnCheckpointCacheSaved(int client, cp_cache_t cpcache, int index, int target) {
	// cpcache.customdata.SetArray("pInfo", g_pInfo[client], sizeof(pInfo), true);
}

public void Shavit_OnCheckpointCacheLoaded(int client, cp_cache_t cpcache, int index) {
	// cpcache.customdata.GetArray("pInfo", g_pInfo[client], sizeof(pInfo));
}

public Action Shavit_OnUserCmdPre(
	int client, int &buttons, int &impulse,
	float vel[3], float angles[3], TimerStatus status,
	int track, int style, int mouse[2]
) {
	if(
		// 计时器拦截 +left/+right 时不检测
		(Shavit_GetStyleSettingBool(style, "block_pleft") && Shavit_GetStyleSettingBool(style, "block_pright"))
		// 起点或计时未开始时不检测
		 || Shavit_GetClientTime(client) == 0.0
		// TAS 模式不检测
		 || Shavit_GetStyleSettingBool(style, "tas")
		// 练习模式不检测
		 || Shavit_IsPracticeMode(client)
	) {
		return Plugin_Continue;
	}

	if (buttons & IN_LEFT) {
		if (g_pInfo[client].iLastButtons != IN_LEFT) {
			OnPlusButtonPressed(client, IN_LEFT);
		}
	} else if (buttons & IN_RIGHT) {
		if (g_pInfo[client].iLastButtons != IN_RIGHT) {
			OnPlusButtonPressed(client, IN_RIGHT);
		}
	}

	// 次数随时间减少
	float fCurTime = GetGameTime();

	if (fCurTime - g_pInfo[client].fLastTime > 1.5 && g_pInfo[client].iCount > 0) {
		g_pInfo[client].iCount--;
		g_pInfo[client].fLastTime = fCurTime;
	}

	return Plugin_Continue;
}

void OnPlusButtonPressed(int client, int plusButton) {
	float fCurTime = g_pInfo[client].fLastTime = GetGameTime();
	g_pInfo[client].iLastButtons = plusButton;

	// 间隔小于侦测时间, iCount++
	if (fCurTime - g_pInfo[client].fLastTime <= 1.5) {
		g_pInfo[client].iCount++;

		// 次数够了, 停止计时
		if (g_pInfo[client].iCount == STOPTIMER_TIMES) {
			Shavit_StopTimer(client);
			CleanUp(client);

			CPrintToChat(
				client, "{red}!!!{white} 计时中止, 尝试连续使用 %s 来获取速度. ({red}%d{white}/%d)",
				plusButton == IN_LEFT ? "{red}+left{white}/+right" : "+left/{red}+right{white}",
				g_pInfo[client].iCount, STOPTIMER_TIMES
			);

			return;
		}
		
		CPrintToChat(
			client, "{white}检测到 {orange}%s{white}. ({orange}%d{white}/%d)",
			plusButton == IN_LEFT ? "+left" : "+right", g_pInfo[client].iCount, STOPTIMER_TIMES
		);

		// 快到次数了, 警告一下
		if (g_pInfo[client].iCount == STOPTIMER_TIMES - 1) {
			CPrintToChat(
				client, "{red}!!! {white}请稍后再使用 %s, 使用过于频繁会导致计时中止!",
				plusButton == IN_LEFT ? "{red}+left{white}/+right" : "+left/{red}+right{white}"
			);
		}
	}
}