--[[Notes:

Client shouldn't create any server functions, only the server should do that & vice versa
]]

--Services--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--Modules--

local Types = require(script.Types)
local Callbacks = require(script.Callbacks)


--Module--

local Network = {}
Network.__index = Network

--Constants--

local THREADS_TEMPLATE = table.freeze {
	Server = {},
	Client = {},
	
	ServerReturnThreads = {},
	ClientReturnThreads = {}
}

--Public Functions--

--Constructor for the networking module
function Network.new(NetworkInfo: Types.NetworkInfo)
	local self = setmetatable({}, Network)
	
	NetworkInfo.Target = if RunService:IsClient() then nil else NetworkInfo.Target or Players:GetPlayers()
	NetworkInfo.ServerFunction = NetworkInfo.ServerFunction or function() end
	NetworkInfo.ClientFunction = NetworkInfo.ClientFunction or function() end
	NetworkInfo.ReturnToServer = NetworkInfo.ReturnToServer or function(...) return ... end
	NetworkInfo.ReturnToClient = NetworkInfo.ReturnToClient or function(...) return ... end
	NetworkInfo.AutoAddPlayers = if RunService:IsClient() then false else NetworkInfo.AutoAddPlayers or false
	
	NetworkInfo.Threads = NetworkInfo.Threads or THREADS_TEMPLATE
	
	for ThreadType, _ in THREADS_TEMPLATE do
		if not NetworkInfo.Threads[ThreadType] then
			THREADS_TEMPLATE[ThreadType] = {}
		end
	end
	
	NetworkInfo.NetworkingDirection = NetworkInfo.NetworkingDirection or "any"

	self.Name = NetworkInfo.Name
	self.NetworkingDirection = NetworkInfo.NetworkingDirection

	self.ServerFunction = NetworkInfo.ServerFunction
	self.ClientFunction = NetworkInfo.ClientFunction

	self.ReturnToServer = NetworkInfo.ReturnToServer
	self.ReturnToClient = NetworkInfo.ReturnToClient
	
	self.AutoAddPlayers = NetworkInfo.AutoAddPlayers
	
	self.Target = NetworkInfo.Target
	
	self.AutoAddPlayersConnection = Players.PlayerAdded:Connect(function(Player)
		if self.AutoAddPlayers then
			table.insert(self.Target, Player)
		else
			self.AutoAddPlayersConnection:Disconnect()
		end
	end)
	
	self.Remote = Callbacks.CreateCallback(NetworkInfo)

	return self
end


--Fires the targets
function Network:FireClient(...)
	assert(RunService:IsServer(), "You're trying to fire clients while on the client. What you're trying to do is stupid.")
	assert(self.NetworkingDirection == "ServerToClient" or self.NetworkingDirection == "any", "You're trying to fire the client while having the networking direction of ClientToServer.")

	for _, Player in ipairs(self.Target) do
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
	self = nil
end


return Network
