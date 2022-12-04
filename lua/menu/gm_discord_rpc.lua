if (file.Find("lua/bin/gmsv_gdiscord_*.dll", "GAME")[1] == nil) then return end

require("gdiscord")

local sid = "" -- https://steamid.io/lookup
local key = "" -- https://steamcommunity.com/dev/apikey

local gameStarted = os.time()
local lastDetails = ""
local detailsTime = os.time()

-- Not saved between game sessions
CreateConVar("rpc_showserverinfo", "1")
CreateConVar("rpc_showgameinfo", "1")

local function updateRPC()
	local convar_showserverinfo = GetConVar("rpc_showserverinfo"):GetBool()
	local convar_showgameinfo = GetConVar("rpc_showgameinfo"):GetBool() and convar_showserverinfo

	local rpc_data = {}
	rpc_data["largeImageKey"] = "logo"

	http.Fetch("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=" .. key .. "&steamids=" .. sid, function(body_user, _, _, code_user)
		if (code_user ~= 200) then return end

		local user = util.JSONToTable(body_user)

		if (not user["response"]["players"]) then return end

		local userData = user["response"]["players"][1]

		local _id = userData["gameserversteamid"]
		local _ip = userData["gameserverip"]

		local ip = (_ip and (_id and _id or nil)) and _ip or "0.0.0.0:0"
		local port = ip:sub(ip:find(":") + 1, #ip)

		if (IsInGame() and convar_showgameinfo) then
			rpc_data["state"] = game.GetMap() .. " [" .. engine.ActiveGamemode() .. "]"
		end

		if (not IsInGame() and ip == "0.0.0.0:0") then
			rpc_data["details"] = "In Menus"

			rpc_data["startTimestamp"] = gameStarted
		end

		if (IsInLoading()) then
			rpc_data["details"] = "Joining a " .. (ip == "0.0.0.0:0" and "game" or "server")

			if (convar_showserverinfo and ip ~= "0.0.0.0:0") then
				rpc_data["state"] = ip
			end
		end

		if (IsInGame() and ip == "0.0.0.0:0") then
			rpc_data["details"] = "Singleplayer"
		end

		if (IsInGame() and ip ~= "0.0.0.0:0" and port == "0") then
			rpc_data["details"] = "Peer-to-peer (P2P)"
		end

		if (IsInGame() and ip ~= "0.0.0.0:0" and port ~= "0") then
			http.Fetch("https://api.steampowered.com/IGameServersService/GetServerList/v1/?key=" .. key .. "&filter=\\addr\\" .. ip, function(body_server, _, _, code_server)
				if (code_server ~= 200) then return end

				local server = util.JSONToTable(body_server)

				if (not server["response"]["servers"]) then return end

				local serverData = server["response"]["servers"][1]

				if (serverData["dedicated"]) then
					rpc_data["details"] = convar_showserverinfo and serverData["name"] or "Multiplayer"

					if (convar_showserverinfo) then
						rpc_data["partySize"] = serverData["players"]
						rpc_data["partyMax"] = serverData["max_players"]

						rpc_data["largeImageText"] = ip
					end
				else
					rpc_data["details"] = "Local Server"
				end

				if (lastDetails == rpc_data["details"]) then
					rpc_data["startTimestamp"] = detailsTime
				else
					rpc_data["startTimestamp"] = os.time()
				end

				lastDetails = rpc_data["details"]
				detailsTime = rpc_data["startTimestamp"]

				DiscordUpdateRPC(rpc_data)
			end)

			return
		end

		if (not rpc_data["startTimestamp"]) then
			if (lastDetails == rpc_data["details"]) then
				rpc_data["startTimestamp"] = detailsTime
			else
				rpc_data["startTimestamp"] = os.time()
			end
		end

		lastDetails = rpc_data["details"]
		detailsTime = rpc_data["startTimestamp"]

		DiscordUpdateRPC(rpc_data)
	end)
end

hook.Add("MenuStart", "DiscordRPC", function()
	DiscordRPCInitialize("1046313703290699828")

	updateRPC()

	timer.Create("DiscordRPCUpdate", 10, 0, updateRPC)
end)