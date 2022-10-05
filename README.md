Plugin to manage the map list. Improved version of the `pingdiscord` SourcePython plugin.

Features:
- Automatically remove maps from the list when played
- Send Discord pings to map authors
- New: Post map notes and thread link in-game every round

# Configuration

- Install the [Feedback Round](https://github.com/TF2Maps/sourcemod-feedbackround) plugin
- Install the [Discord API](https://forums.alliedmods.net/showthread.php?t=292663) plugin
- Add a `maplist` connection to SourceMod's `configs/databases.cfg`
- Add a `maplistbridge` webhook URL to `configs/discord.cfg`
- Set the `maplistbridge_ip` ConVar to the server's IP (eg. `eu.tf2maps.net`)

Optional:
- Change `maplistbridge_players` (default `4`) to set the number of players required to consider the map played