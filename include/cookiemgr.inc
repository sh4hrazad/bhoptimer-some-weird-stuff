#if defined COOKIEMGR_INC
        #endinput
#endif
#define COOKIEMGR_INC

enum CookieType {
	CT_Integer = 0,
	CT_Boolean,
	CT_Float
};

stock Cookie freshmanCookie;

stock void RegisterFreshmanCookie(const char[] prefix) {
        char buffer[64];
        FormatEx(buffer, sizeof(buffer), "[%s] Freshman", prefix);

        freshmanCookie = new Cookie(buffer, buffer, CookieAccess_Protected);
}

stock bool IsFreshman(int client) {
        return !GetCookie(client, freshmanCookie, CT_Boolean);
}

stock void SetFreshmanCookie(int client) {
        SetCookie(client, freshmanCookie, CT_Boolean, true);
}

stock void SetCookie(int client, Cookie cookie, CookieType type, any value) {
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

stock any GetCookie(int client, Cookie cookie, CookieType type) {
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