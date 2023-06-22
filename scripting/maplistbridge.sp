#include <sourcemod>

#include <feedback2> // https://github.com/TF2Maps/sourcemod-feedbackround
#include <discord> // https://forums.alliedmods.net/showthread.php?t=292663

#pragma semicolon 1
#pragma newdecls required

#define DATABASE_NAME "maplist"
#define QUERY_GET_MAP_DATA "SELECT discord_user_id, url, notes FROM maps WHERE map='%s' AND status='pending' LIMIT 1"
#define QUERY_SET_MAP_PLAYED  "UPDATE maps SET status='played', played=now() WHERE map='%s' AND status='pending'"

#define WEBHOOK_NAME "maplistbridge"
#define WEBHOOK_DATA "{\"username\": \"Mecha Engineer\", \"content\": \"<@%s> %s is currently being played on https://bot.tf2maps.net/%s with %d players.\"}"

public Plugin myinfo = {
	name = "Map List Bridge",
	author = "Mr. Burguers",
	description = "Operations related to the map list",
	version = "1.2",
	url = "https://tf2maps.net/home/"
};

Database g_hConn;

ConVar g_hCVarServerIP;
ConVar g_hCVarMinPlayers;

ConVar g_hTVEnabled;

char g_sMapName[64];
char g_sDiscordID[64];
char g_sMapURL[240];
bool g_bHasNotes;
char g_sMapNotes[240];

bool g_bDataLoaded;
bool g_bMapRemoved;
int g_iConnectedPlayers;

public void OnPluginStart() {
	g_hCVarServerIP = CreateConVar("maplistbridge_ip", "unknown", "Server redirection page on the bot URL.", 0);
	g_hCVarMinPlayers = CreateConVar("maplistbridge_players", "4", "Minimum players to consider the map as played.", 0, true, 1.0, true, 32.0);

	g_hTVEnabled = FindConVar("tv_enable");

	HookEvent("teamplay_round_start", SendNotes, EventHookMode_PostNoCopy);
	HookEvent("player_team", CheckMap, EventHookMode_PostNoCopy);

	ConnectToDatabase();
}

public void OnPluginEnd() {
	UnhookEvent("teamplay_round_start", SendNotes, EventHookMode_PostNoCopy);
	UnhookEvent("player_team", CheckMap, EventHookMode_PostNoCopy);

	DisconnectFromDatabase();
}

public void OnMapStart() {
	g_bDataLoaded = false;
	g_bMapRemoved = false;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	if (g_hConn != null || ConnectToDatabase()) {
		RetrieveMapData();
	}
}

void RetrieveMapData() {
	char sQuery[1024];
	g_hConn.Format(sQuery, sizeof(sQuery), QUERY_GET_MAP_DATA, g_sMapName);
	g_hConn.Query(OnMapDataRetrieved, sQuery);
}

void OnMapDataRetrieved(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		LogError("MapListBridge SQL error - %s", error);
		return;
	}
	if (!results.FetchRow()) {
		// Map is not in the list
		return;
	}

	results.FetchString(0, g_sDiscordID, sizeof(g_sDiscordID));
	results.FetchString(1, g_sMapURL, sizeof(g_sMapURL));
	g_bHasNotes = false;
	if (!results.IsFieldNull(2)) {
		results.FetchString(2, g_sMapNotes, sizeof(g_sMapNotes));
		int iNoteLength = strlen(g_sMapNotes);
		if (iNoteLength > 0) {
			g_bHasNotes = true;
			// Replace ending with "(...)" if notes didn't fit
			if (iNoteLength == sizeof(g_sMapNotes) - 1) {
				strcopy(g_sMapNotes[sizeof(g_sMapNotes) - 6], 6, "(...)");
			}
		}
	}

	g_bDataLoaded = true;
}

void SendNotes(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bDataLoaded || FB2_IsFbRoundActive()) {
		return;
	}

	if (g_bHasNotes) {
		PrintToChatAll("\x01------- \x04Map Notes \x01-------");
		PrintToChatAll("%s", g_sMapNotes);
		PrintToChatAll("-------------------------");
	}

	PrintToChatAll("\x04Map Thread\x01: %s", g_sMapURL);
}

void CheckMap(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bDataLoaded || g_bMapRemoved) {
		return;
	}

	g_iConnectedPlayers = GetConnectedPlayers();
	int iPlayersNeeded = g_hCVarMinPlayers.IntValue;
	if (g_iConnectedPlayers >= iPlayersNeeded) {
		g_bMapRemoved = true;
		RemoveMapFromQueue();
	}
}

void RemoveMapFromQueue() {
	char sQuery[1024];
	g_hConn.Format(sQuery, sizeof(sQuery), QUERY_SET_MAP_PLAYED, g_sMapName);
	g_hConn.Query(OnMapRemovedFromQueue, sQuery);
}

void OnMapRemovedFromQueue(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		LogError("MapListBridge SQL error - %s", error);
		g_bMapRemoved = false;
		return;
	}

	SendDiscordMessage();
}

void SendDiscordMessage() {
	char sServerIP[64];
	g_hCVarServerIP.GetString(sServerIP, sizeof(sServerIP));

	char sBody[1024];
	Format(sBody, sizeof(sBody), WEBHOOK_DATA, g_sDiscordID, g_sMapName, sServerIP, g_iConnectedPlayers);

	Discord_SendMessage(WEBHOOK_NAME, sBody);
}

// ---------- Utility functions ---------- //

int GetConnectedPlayers() {
	int iPlayerCount = GetClientCount(false); // Do count connecting clients
	if (g_hTVEnabled.BoolValue) {
		iPlayerCount--;
	}

	return iPlayerCount;
}

bool ConnectToDatabase() {
	char sError[256];
	g_hConn = SQL_Connect(DATABASE_NAME, true, sError, sizeof(sError));

	if (g_hConn == null) {
		LogError("Failed to connect - %s", sError);
		return false;
	} else {
		LogMessage("Connected to database");
		return true;
	}
}

void DisconnectFromDatabase() {
	delete g_hConn;
}
