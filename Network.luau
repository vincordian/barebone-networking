--[[Notes:

client & server can only create their respective functions
it'll error if you have a client network but not a server one

'Target' will fallback to every *current* player if not specified, or you can provide an empty table.
using self.Remote will use orthodox RemoteEvent methods instead
self.Implicit like a buffer if that's how you say it

note that on server, the first argument in type checking isnt counted as it is always expected to be a player

]]

--!native


--Constants--

local WAIT_FOR_CHILD_TIMEOUT = 10


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

		Target : {[number]:Player}, --targets for firing client
		AutoAddPlayers: boolean, --self explanatory

		ClientFunctionCalledOnReturn: boolean, --pretty self explanatory
		ReturnToClient: (Player, any) -> (any), --will fire client back with this function's return

	},

	Anticheat: {

		AnticheatFunction: (Player, any) -> (boolean), --if it returns false/nil then it will exit the current thread

	},

	Functions: {

		ClientFunction: (Player, any) -> (), --fires on OnClientEvent
		ServerFunction: (Player, any) -> (), --fired on OnServerEvent

	},

	TypeChecking: {

		AllowedTypes:{any}|nil, --if it detects anything not in list of allowed types (case sensitive, also check your spelling) then it will 
		DisallowedTypes:{any}|nil,

		AllowedTypesFunction: (any) -> (boolean),
		DisallowedTypesFunction: (any) -> (boolean),
		--parameters: type,
		--if it returns false/nil then it will exit that current thread

	},

}


--Module--

local Network = {}
Network.__index = Network


--Private Functions-- (had to place this infront as I need the network table for this to work)

--constructs self to be used in colon notattion functions
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

		TypeChecking = NetworkInfo.TypeChecking and {

			AllowedTypes = NetworkInfo.TypeChecking.AllowedTypes,
			DisallowedTypes = NetworkInfo.TypeChecking.DisallowedTypes,

		},

	} :: NetworkInfo

	self.Implicit = {} --stores internal stuff like a buffer


	if self.ServerToClient and self.ServerToClient.AutoAddPlayers then

		self.Implicit.AutoAddPlayersConnection = Players.PlayerAdded:Connect(function(Player)

			if not table.find(self.ServerToClient.Target, Player) then
				table.insert(self.ServerToClient.Target, Player)
			end
		end)
	end

	setmetatable(self, Network)

	return self
end


--pretty self explanatory
local function setupFoldersAndRemotes(self)

	local Folder = ReplicatedStorage:FindFirstChild("NetworkRemotes")

	if not Folder then
		if RunService:IsClient() then
			Folder = ReplicatedStorage:WaitForChild("NetworkRemotes", WAIT_FOR_CHILD_TIMEOUT)
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
			self.Remote = Folder:WaitForChild(self.Main.Name, WAIT_FOR_CHILD_TIMEOUT)
			assert(self.Remote, "No remote for network found.")
		else
			self.Remote = Instance.new("RemoteEvent")
			self.Remote.Name = self.Main.Name
			self.Remote.Parent = Folder
		end
	end


	if RunService:IsServer() and self.Main.NetworkingDirection ~= "ServerToClient" then

		self.Implicit.OnServerEvent = self.Remote.OnServerEvent:Connect(function(Player:Player, ...)

			local Arguments = {...}

			if self.Typechecking and self.Typechecking.AllowedTypes then

				for _, Type:unknown in Arguments do
					if not table.find(self.Typechecking.AllowedTypes, typeof(Type)) then
						if self.Typechecking.AllowedTypesFunction and not self.Typechecking.AllowedTypesFunction(Type) then return end
					end
				end
			end

			if self.Typechecking and self.Typechecking.DisallowedTypes then

				for _, Type:unknown in Arguments do
					if table.find(self.Typechecking.DisallowedTypes, typeof(Type)) then
						if self.Typechecking.DisallowedTypesFunction and not self.Typechecking.DisallowedTypesFunction(Type) then return end
					end
				end
			end


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

	if RunService:IsClient() and self.Main.NetworkingDirection ~= "ClientToServer" then

		self.Implicit.OnClientEvent = self.Remote.OnClientEvent:Connect(function(...)

			local Arguments = {...}

			if self.Typechecking and self.Typechecking.AllowedTypes then

				for _, Type:unknown in Arguments do
					if not table.find(self.Typechecking.AllowedTypes, typeof(Type)) then
						if self.Typechecking.AllowedTypesFunction and self.Typechecking.AllowedTypesFunction(Type) then return end
					end
				end
			end

			if self.Typechecking and self.Typechecking.DisallowedTypes then

				for _, Type:unknown in Arguments do
					if table.find(self.Typechecking.DisallowedTypes, typeof(Type)) then
						if self.Typechecking.DisallowedTypesFunction and self.Typechecking.AllowedTypesFunction(Type) then return end
					end
				end
			end


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


--Public Functions--

--[=[

	Main = {

			Name = assert(NetworkInfo.Main.Name, "Network has no name."), --assert returns the input which is nice
			NetworkingDirection = assert(NetworkInfo.Main.NetworkingDirection, "Network has no NetworkingDirection.")

		},

		ServerToClient = NetworkInfo.ServerToClient and {

			Target = NetworkInfo.ServerToClient.Target or Players:GetPlayers(), --or keyword will divert the assignment to the next statement thingy
			AutoAddPlayers = NetworkInfo.ServerToClient and NetworkInfo.ServerToClient.AutoAddPlayers or false, --and keyword will check if first condition isn't false/nil, and diverts it into another condition if so

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

]=]
function Network.new(NetworkInfo: NetworkInfo)

	--Important to do this first, as if done in the later IsServer & isClient and throws an error, will waste memory

	if RunService:IsServer() then
		if NetworkInfo.Functions then
			assert(not NetworkInfo.Functions.ClientFunction, "ClientFunction is only supported on the client")
		end
	end

	if RunService:IsClient() then
		if NetworkInfo.Functions then
			assert(not NetworkInfo.Functions.ServerFunction, "ServerFunction is only supported on the server")
		end
	end


	local self = setupSelf(NetworkInfo) --lowercase to match self keyword
	setupFoldersAndRemotes(self)

	return self
end


--Fires the targets, to fire a specific one try self.Remote:FireClient(Player, ...)
function Network:FireClient(...)

	assert(RunService:IsServer(), "FireClient is only supported on the server.")
	assert(self.Main.NetworkingDirection == "ServerToClient" or self.Main.NetworkingDirection == "any", "You're trying to fire the client while having the networking direction of ClientToServer.")

	for _, Player:Player in self.ServerToClient.Target do
		self.Remote:FireClient(Player, ...)
	end

	return self
end


function Network:FireServer(...)

	assert(RunService:IsClient(), "FireServer is only supported on the client")
	assert(self.Main.NetworkingDirection == "ClientToServer" or self.Main.NetworkingDirection == "any", "You're trying to fire the Server while having the networking direction of ServerToClient.")

	self.Remote:FireServer(...)

	return self
end


--Should be used on the server to end all the clients
function Network:End()

	if self.Remote then
		self.Remote:Destroy()
	end

	if self.Implicit then

		if RunService:IsClient() and self.Implicit.OnClientEvent then

			self.Implicit.OnClientEvent:Disconnect()

		elseif RunService:IsServer() and self.Implicit.OnServerEvent then
			
			self:EndAutoPlayers()

			self.Implicit.OnServerEvent:Disconnect()
		end
	end

	--GC since i don't think its removed afterwards
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end


function Network:EndAutoPlayers()

	assert(not RunService:IsClient(), "EndAutoPlayers is only supported on the server.")


	if self.Implicit.AutoAddPlayersConnection then
		self.Implicit.AutoAddPlayersConnection:Disconnect()
		self.Implicit.AutoAddPlayersConnection = nil --GC, again
	end


	return self.Target
end


return Network
