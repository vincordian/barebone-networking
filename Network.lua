--[[Notes:

Client shouldn't create any server functions, only the server should do that

Client should only have a return to server, client function, threads and name


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


--Public Functions--

--Constructor for the networking module
function Network.new(NetworkInfo: Types.NetworkInfo, Threads: Types.Threads)
	local self = setmetatable({}, Network)
	
	NetworkInfo.Target = NetworkInfo.Target or Players:GetPlayers()
	NetworkInfo.ServerFunction = NetworkInfo.ServerFunction or function() end
	NetworkInfo.ClientFunction = NetworkInfo.ClientFunction or function() end
	NetworkInfo.ReturnToServer = NetworkInfo.ReturnToServer or function() end
	NetworkInfo.ReturnToClient = NetworkInfo.ReturnToClient or function() end
	
	Threads = Threads or {
		Server = {},
		Client = {}
	}
	
	NetworkInfo.NetworkingDirection = NetworkInfo.NetworkingDirection or "any"

	self.Name = NetworkInfo.Name
	self.NetworkingDirection = NetworkInfo.NetworkingDirection

	self.ServerFunction = NetworkInfo.ServerFunction
	self.ClientFunction = NetworkInfo.ClientFunction

	self.ReturnToServer = NetworkInfo.ReturnToServer
	self.ReturnToClient = NetworkInfo.ReturnToClient

	self.Target = NetworkInfo.Target

	assert(#self.Target > 0, "You're providing an empty target table for the client firing. What you're trying to do is stupid.")
	
	self.Threads = Threads
	
	self.Remote = Callbacks.CreateCallback(NetworkInfo, Threads)

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


return Network
