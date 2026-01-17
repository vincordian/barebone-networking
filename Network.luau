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

		Target : {[number]:Player}, --targets for firing client, if empty then it will default to all CURRENT players, serversided
		AutoAddPlayers: boolean, --self explanatory, serversided

		ClientFunctionCalledOnReturn: boolean, --pretty self explanatory, clientsided
		ReturnToClient: (Player, any) -> (any), --will fire client back with this function's return, serversided (basically a remote function, but only the server can return a value)

	},

	Anticheat: {

		AnticheatFunction: (Player, any) -> (boolean), --if it returns false/nil then it will exit the current thread, serversided

	},

	Functions: {

		ClientFunction: (Player, any) -> (), --fires on OnClientEvent ..which means clientsided
		ServerFunction: (Player, any) -> (), --fired on OnServerEvent ..which means serversided

	},

	TypeChecking: {
		
		--all of these are serversided
		--Keep in mind these are DICTIONARY LISTS not number arrays due to the time complexity of table.find() being worse
		AllowedTypes:{any}|nil, --if it detects anything not in list of allowed types (case sensitive, also check your spelling) then it will exit the current thread
		DisallowedTypes:{any}|nil,

		AllowedTypesFunction: (any) -> (boolean),
		DisallowedTypesFunction: (any) -> (boolean),
		--parameters: type,
		--if it returns false/nil then it will exit that current thread
		--aka if it returns error code "not true"

	},

}


--Module--

local Network = {}
Network.__index = Network


--Private Functions-- (had to place this infront as I need the network table for this to work)

--constructs self to be used in colon notation functions
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

			ClientCalledOnReturn = NetworkInfo.ServerToClient and NetworkInfo.ServerToClient.ClientFunctionCalledOnReturn or false,
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


local function checkTypes(self, ...)
	
	if not self.TypeChecking then return true end
	
	local Arguments = {...}
	
	for _, Argument in Arguments do
		
		if self.TypeChecking.AllowedTypes and self.TypeChecking.AllowedTypes[typeof(Argument)] ~= true then
			return false
		end
		
		if self.TypeChecking.DisallowedTypes and self.TypeChecking.DisallowedTypes[typeof(Argument)] then
			return false
		end
		
		if self.TypeChecking.AllowedTypesFunction and not self.TypeChecking.AllowedTypesFunction(Argument) then
			return false
		end
		
		if self.TypeChecking.DisallowedTypesFunction and not self.TypeChecking.DisallowedTypesFunction(Argument) then
			return false
		end
	end
	
	return true
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
			
			if self.Main.NetworkingDirection == "ServerToClient" then warn(`Player {Player} is sending remote signals to server even though the NetworkingDirection is {self.Main.NetworkingDirection}\n exiting current network thread.`) return end

			local Arguments = {...}

			if not checkTypes(self, ...) then return end


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

			checkTypes(self, ...)
			

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


--Fires the targets in network constructor, to fire a specific one try self.Remote:FireClient(Player, ...)
function Network:FireClientTargets(...)

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


--Incase you need a special occasion that requires you to fire specific clients e.g. specific vfx's
function Network:FireSpecificClients(Players: {Player}|Player, ...)
	
	assert(RunService:IsServer(), "FireSpecificClients is only supported on the server")
	assert(self.Main.NetworkingDirection == "ServerToClient" or self.Main.NetworkingDirection == "any", "You're trying to fire the client while having the networking direction of ClientToServer.")
	
	if typeof(Players) == "Instance" then
		self.Remote:FireClient(Players, ...) --if its not a table and instead just a player
	else
		for _, Player:Player in Players do
			self.Remote:FireClient(Player, ...)
		end
	end
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
