--[[Notes:

client & server can only create their respective functions
it'll error if you have a client network but not a server one

]]

--!native

--Services--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


--Types--

export type NetworkInfo = {

	Main: {
		Name: string,
		NetworkingDirection: "ClientToServer"|"ServerToClient"|"any",
	},

	ServerToClient: {
		Target : {[number]:Player},
		AutoAddPlayers: boolean,

		ClientFunctionCalledOnReturn: boolean,
		ReturnToClient: (any) -> (any),
	},

	Anticheat: {
		AnticheatFunction: (any) -> (boolean),
	},

	Functions: {
		ClientFunction: (any) -> (),
		ServerFunction: (any) -> ()
	}
	
}


--Module--

local Network = {}
Network.__index = Network


--Private Functions-- (had to place this infront as I need the network table for this to work)

local function setupSelf(NetworkInfo: NetworkInfo)

	assert(NetworkInfo, "You didn't even provide NetworkInfo what are you doing..")
	assert(NetworkInfo.Main, "No network main")

	local self = {

		Main = {
			Name = assert(NetworkInfo.Main.Name, "Network has no name."),
			NetworkingDirection = assert(NetworkInfo.Main.NetworkingDirection, "Network has no NetworkingDirection.")
		},

		ServerToClient = NetworkInfo.ServerToClient and {

			Target = NetworkInfo.ServerToClient.Target or Players:GetPlayers(),
			AutoAddPlayers = NetworkInfo.ServerToClient and NetworkInfo.ServerToClient.AutoAddPlayers or false,

			ClientCalledOnReturn = NetworkInfo.ServerToClient and NetworkInfo.ServerToClient.ClientCalledOnReturn or false,
			ReturnToClient = NetworkInfo.ServerToClient.ReturnToClient,

		},

		Anticheat = NetworkInfo.Anticheat and {

			AnticheatFunction = NetworkInfo.Anticheat.AnticheatFunction,

		},

		Functions = NetworkInfo.Functions and {

			ClientFunction = NetworkInfo.Functions.ClientFunction,
			ServerFunction = NetworkInfo.Functions.ServerFunction,

		},

	}

	
	if self.ServerToClient and self.ServerToClient.AutoAddPlayers then
		self.AutoAddPlayersConnection = Players.PlayerAdded:Connect(function(Player)
			if not table.find(self.ServerToClient.Target, Player) then
				table.insert(self.ServerToClient.Target, Player)
			end
		end)
	end
	

	return self
end

--Public Functions--

--[=[

	Main: {
		Name: string,
		NetworkingDirection: "ClientToServer"|"ServerToClient"|"any",
	},

	ServerToClient: {
		Target : {[number]:Player},
		AutoAddPlayers: boolean,

		ClientFunctionCalledOnReturn: boolean,
		ReturnToClient: (any) -> (any),
	},

	Anticheat: {
		AnticheatFunction: (any) -> (boolean),
	},

	Functions: {
		ClientFunction: (any) -> (),
		ServerFunction: (any) -> ()
	}

]=]
function Network.new(NetworkInfo: NetworkInfo)
	
	assert(NetworkInfo.Main.Name, "No name provided for the network")
	assert(NetworkInfo.Main.NetworkingDirection, `No networking direction for {NetworkInfo.Main.Name}`)

	--Important to do this first, as if done in the later IsServer & isClient and throws an error, will waste memory

	if RunService:IsServer() then
		if NetworkInfo.Functions then
			assert(not NetworkInfo.Functions.ClientFunction, "You're trying to create a client function while on the server. What you're trying to do is stupid.")
		end
	end

	if RunService:IsClient() then
		if NetworkInfo.Functions then
			assert(not NetworkInfo.Functions.ServerFunction, "You're trying to create a server function while on the client. What you're trying to do is stupid.")
			assert(not NetworkInfo.ServerToClient.ReturnToClient, "You're trying to create a client return while on the client. What you're trying to do is stupid.")
		end
	end


	local self = setupSelf(NetworkInfo)


	--a really good way to remove local variables if you don't want them
	--aka too lazy to create another function
	do
		local Folder = ReplicatedStorage:FindFirstChild("NetworkRemotes")

		if not Folder then
			if RunService:IsClient() then
				Folder = ReplicatedStorage:WaitForChild("NetworkRemotes", 10)
				assert(Folder, "No folder for network found.")
			else
				Folder = Instance.new("Folder")
				Folder.Name = "NetworkRemotes"
				Folder.Parent = ReplicatedStorage
			end
		end

		self.Remote = Folder:FindFirstChild(self.Main.Name)

		if not self.Remote then
			if RunService:IsClient() then
				self.Remote = Folder:WaitForChild(self.Main.Name, 10)
				assert(self.Remote, "No remote for network found.")
			else
				self.Remote = Instance.new("RemoteEvent")
				self.Remote.Name = self.Main.Name
				self.Remote.Parent = Folder
			end
		end


		if RunService:IsServer() then
			self.Remote.OnServerEvent:Connect(function(Player:Player, ...)

				if self.Anticheat and self.Anticheat.AnticheatFunction and not self.Anticheat.AnticheatFunction(Player, ...) then

					warn(`Anticheat triggered by {Player.Name}`)

					return
				end

				if self.Functions and self.Functions.ServerFunction then self.Functions.ServerFunction(Player, ...) end

				if self.ServerToClient and self.ServerToClient.ReturnToClient then
					self.Remote:FireClient(Player, self.ServerToClient.ReturnToClient(Player, ...), "__return")
				end
			end)
		end

		if RunService:IsClient() then
			self.Remote.OnClientEvent:Connect(function(...)

				local Arguments = {...}

				if self.Functions and self.Functions.ClientFunction then

					if table.find(Arguments, "__return") then
						if self.ServerToClient and self.ServerToClient.ClientFunctionCalledOnReturn then
							if self.Functions and self.Functions.ClientFunction then self.Functions.ClientFunction(...) end
						end

						return
					end

					self.Functions.ClientFunction(...)
				end
			end)
		end

	end

	return self
end


--Fires the targets, to fire a specific one try self.Remote:FireClient(Player, ...)
function Network:FireClient(...)
	assert(RunService:IsServer(), "You're trying to fire clients while on the client. What you're trying to do is stupid.")
	assert(self.Main.NetworkingDirection == "ServerToClient" or self.Main.NetworkingDirection == "any", "You're trying to fire the client while having the networking direction of ClientToServer.")

	for _, Player:Player in self.Target do
		self.Remote:FireClient(Player, ...)
	end

	return self
end


function Network:FireServer(...)
	assert(RunService:IsClient(), "You're trying to fire server while on the server. What you're trying to do is stupid.")
	assert(self.Main.NetworkingDirection == "ClientToServer" or self.Main.NetworkingDirection == "any", "You're trying to fire the Server while having the networking direction of ServerToClient.")

	self.Remote:FireServer(...)

	return self
end


--Should be used on the server
function Network:End()
	assert(RunService:IsServer(), "You're trying to end the network while on the client. What you're trying to do is stupid.")
	self.Remote:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end



function Network:EndAutoPlayers()
	assert(not RunService:IsClient(), "You're trying to end auto players connection while on the client. What you're trying to do is stupid.")
	self.AutoAddPlayersConnection:Disconnect()
	self.AutoAddPlayersConnection = nil

	return self.Target
end


return Network
