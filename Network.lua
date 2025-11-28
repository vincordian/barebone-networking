--[[Notes:

Client shouldn't create any server functions, only the server should do that & vice versa

Server & client share separate modules, and only connect by a remote.
For example, you create Network.new {Name = "Test", ClientFunction = function() end}, the client function will only work if you're on the client as they share different metatables.
I was gonna let it do the opposite, letting the server give the client to run functions, but that's already possible with the returns
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

--[=[
e.g.
local Network = Network.new {
	Name = "HelloWorld",
	Target = {Players:FindFirstChild("Player1"), Players:FindFirstChild("Player2")},
	ServerFunction = function(...)--"..." is an unpacked table of arguments sent when firing with :FireServer()/:FireClient()
		print(...)
	end
}
]=]
function Network.new(NetworkInfo: Types.NetworkInfo)
	local self = setmetatable({}, Network)

	if RunService:IsServer() then assert(not NetworkInfo.ClientFunction, "You're trying to create a client function while on the server. What you're trying to do is stupid.") assert(not NetworkInfo.ReturnToServer, "You're trying to create a server return while on the server. What you're trying to do is stupid.") end
	if RunService:IsClient() then assert(not NetworkInfo.ServerFunction, "You're trying to create a server function while on the client. What you're trying to do is stupid.") assert(not NetworkInfo.ReturnToClient, "You're trying to create a client return while on the client. What you're trying to do is stupid.") end

	NetworkInfo.Target = if RunService:IsClient() then {} else NetworkInfo.Target or Players:GetPlayers()
	NetworkInfo.ServerFunction = NetworkInfo.ServerFunction or function() end
	NetworkInfo.ClientFunction = NetworkInfo.ClientFunction or function() end
	NetworkInfo.ReturnToServer = NetworkInfo.ReturnToServer or function(...) return ... end
	NetworkInfo.ReturnToClient = NetworkInfo.ReturnToClient or function(...) return ... end
	NetworkInfo.AutoAddPlayers = if RunService:IsClient() then false else NetworkInfo.AutoAddPlayers or false

	NetworkInfo.Threads = NetworkInfo.Threads or THREADS_TEMPLATE

	for ThreadType, _ in THREADS_TEMPLATE do
		if not NetworkInfo.Threads[ThreadType] then
			NetworkInfo.Threads[ThreadType] = {}
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
