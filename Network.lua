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

	Name: string, --Name of the remote

	NetworkingDirection: "ClientToServer"|"ServerToClient"|"any", --Great if you don't want any accidents to happen

	Target: {Player}|nil, --Will fire all clients if nil

	ServerFunction: (any) -> (nil), --Fires when OnServerEvent ends
	ClientFunction: (any) -> (nil), --Fires when OnClientEvent ends

	ClientFunctionCalledOnReturn: boolean, --Controls if the client function gets called on return

	ReturnToClient: (any) -> (any)|true|false|nil, --If true, will use default function of function(Player, ...) return ... end, or the function provided if any

	AutoAddPlayers: boolean, --Will automatically add players left out to the target table if true

	Threads: {
		Server: {(any) -> (any)},--Secondary server functions basically
		Client: {(any) -> (any)}, --Secondary client functions basically


		ClientReturnThreads: {(any) -> (any)}, --Fires when server returns data
	},

	AnticheatFunction: (any) -> (boolean),
	
	KickOnAnticheatTrigger:boolean
}


--Module--

local Network = {}
Network.__index = Network


--Constants--

local THREADS_TEMPLATE = {
	Server = {},
	Client = {},

	ClientReturnThreads = {}
}


--Public Functions--

--[=[

	Name: string, --Name of the remote

	NetworkingDirection: "ClientToServer"|"ServerToClient"|"any", --Great if you don't want any accidents to happen

	Target: {Player}|nil, --Will fire all clients if nil

	ServerFunction: (any) -> (nil), --Fires when OnServerEvent ends
	ClientFunction: (any) -> (nil), --Fires when OnClientEvent ends

	ClientFunctionCalledOnReturn: boolean, --Controls if the client function gets called on return

	ReturnToClient: (any) -> (any), --Fires when client fires the remote, the server fires to client back with data

	AutoAddPlayers: boolean, --Will automatically add players left out to the target table if true

	Threads: {
		Server: {(any) -> (any)},--Secondary server functions basically
		Client: {(any) -> (any)}, --Secondary client functions basically


		ClientReturnThreads: {(any) -> (any)}, --Fires when server returns data
	},

	AnticheatFunction: (any) -> (boolean)

]=]
function Network.new(NetworkInfo: NetworkInfo)
	
	assert(NetworkInfo.Name, "No name provided for the network")
	
	--Important to do this first, as if done in the later IsServer & isClient and throws an error, will waste memory
	
	if RunService:IsServer() then
		assert(not NetworkInfo.ClientFunction, "You're trying to create a client function while on the server. What you're trying to do is stupid.")
	end
	
	if RunService:IsClient() then
		assert(not NetworkInfo.ServerFunction, "You're trying to create a server function while on the client. What you're trying to do is stupid.")
		assert(not NetworkInfo.ReturnToClient, "You're trying to create a client return while on the client. What you're trying to do is stupid.")
	end
	
	
	local self = setmetatable({}, Network)
	
	self.Name = NetworkInfo.Name
	self.NetworkingDirection = NetworkInfo.NetworkingDirection or "any"
	
	self.Target = if RunService:IsClient() then {} else NetworkInfo.Target or Players:GetPlayers()
	
	self.ServerFunction = NetworkInfo.ServerFunction or function() end
	self.ClientFunction = NetworkInfo.ClientFunction or function() end
	
	self.ClientFunctionCalledOnReturn = NetworkInfo.ClientFunctionCalledOnReturn or false
	
	self.ReturnToClient = if NetworkInfo.ReturnToClient then NetworkInfo.ReturnToClient elseif NetworkInfo.ReturnToClient == true then function(Player, ...) return ... end else NetworkInfo.ReturnToClient
	
	self.AutoAddPlayers = if RunService:IsClient() then false else NetworkInfo.AutoAddPlayers or false
	
	self.Threads = NetworkInfo.Threads or table.clone(THREADS_TEMPLATE)
	
	self.KickOnAnticheatTrigger = NetworkInfo.KickOnAnticheatTrigger or false
	
	for ThreadType, _ in THREADS_TEMPLATE do
		if not self.Threads[ThreadType] then
			self.Threads[ThreadType] = {}
		end
	end
	
	
	self.AnticheatFunction = NetworkInfo.AnticheatFunction or function() return true end
	
	
	if self.AutoAddPlayers then
		self.AutoAddPlayersConnection = Players.PlayerAdded:Connect(function(Player)
			table.insert(self.Target, Player)
		end)
	end
	
	
	
	--a really good way to remove local variables if you don't want them
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
		
		self.Remote = Folder:FindFirstChild(self.Name)
		
		
		if not self.Remote then
			if RunService:IsClient() then
				self.Remote = Folder:WaitForChild(self.Name, 10)
				assert(self.Remote, "No remote for network found.")
			else
				self.Remote = Instance.new("RemoteEvent")
				self.Remote.Name = self.Name
				self.Remote.Parent = Folder
			end
		end
		
		
		if RunService:IsServer() then
			self.Remote.OnServerEvent:Connect(function(Player:Player, ...)
				
				if self.AnticheatFunction(Player, ...) then
					
					warn(`Anticheat triggered by {Player}`)
					if self.KickOnAnticheatTrigger then pcall(function() Player:Kick() end) end
					
					return
				end
				
				
				self.ServerFunction(Player, ...)
				
				
				if self.ReturnToClient then
					if type(self.ReturnToClient) == "function" then
						self.Remote:FireClient(Player, self.ReturnToClient(Player, ...), "__return")
					end
					
					self.Remote:FireClient(Player, ..., "__return")
				end

				for _, func in self.Threads.Server do
					func(Player, ...)
				end
			end)
		end


		if RunService:IsClient() then
			self.Remote.OnClientEvent:Connect(function(...)

				local Arguments = {...}

				if table.find(Arguments, "__return") then
					if self.ClientFunctionCalledOnReturn then
						self.ClientFunction(...)
					end

					return
				end

				self.ClientFunction(...)

				for _, func in self.Threads.Client do
					func(...)
				end
			end)
		end

	end

	return self
end


--Fires the targets
function Network:FireClient(...)
	assert(RunService:IsServer(), "You're trying to fire clients while on the client. What you're trying to do is stupid.")
	assert(self.NetworkingDirection == "ServerToClient" or self.NetworkingDirection == "any", "You're trying to fire the client while having the networking direction of ClientToServer.")

	for _, Player:Player in self.Target do
		self.Remote:FireClient(Player, ...)
	end

	return self
end


--Fires the server
function Network:FireServer(...)
	assert(RunService:IsClient(), "You're trying to fire server while on the server. What you're trying to do is stupid.")
	assert(self.NetworkingDirection == "ClientToServer" or self.NetworkingDirection == "any", "You're trying to fire the Server while having the networking direction of ServerToClient.")

	self.Remote:FireServer(...)

	return self
end


--Ends the network, should be used on the server
function Network:End()
	assert(RunService:IsServer(), "You're trying to end the network while on the client. What you're trying to do is stupid.")
	self.Remote:Destroy()
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end


--Ends auto add player connection
function Network:EndAutoAddPlayerConnection()
	self.AutoAddPlayersConnection:Disconnect()
	self.AutoAddPlayersConnection = nil

	return self.Target
end


return Network
