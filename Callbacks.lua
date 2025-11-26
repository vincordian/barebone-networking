--I don't know why I named this file callbacks.

--Services--

local ReplicatedStorage = game:GetService("ReplicatedStorage")


--Modules--

local Types = require(script.Parent.Types)


--Module--

local Callbacks = {}


--Public Functions--

--Creates a callback--
function Callbacks.CreateCallback(NetworkInfo: Types.NetworkInfo)
	local Folder = ReplicatedStorage:FindFirstChild("NetworkRemotes")
	if not Folder then
		Folder = Instance.new("Folder")
		Folder.Name = "NetworkRemotes"
		Folder.Parent = ReplicatedStorage
	end

	local Remote = Instance.new("RemoteEvent") do
		assert(not ReplicatedStorage:FindFirstChild(NetworkInfo.Name), `A remote was found with the name of {NetworkInfo.Name} whilst creating a remote with the same name, please rename that remote`)

		Remote.Name = NetworkInfo.Name
		Remote.Parent = Folder

		Remote.OnServerEvent:Connect(function(...)

			local Arguments = {...}

			if table.find(Arguments, "__return") then
				return Arguments
			end

			for _, Player in ipairs(NetworkInfo.Target) do
				Remote:FireClient(Player, NetworkInfo.ReturnToClient(...), "__return")
			end


			NetworkInfo.ServerFunction(...)
		end)

		Remote.OnClientEvent:Connect(function(...)
			local Arguments = {...}

			if table.find(Arguments, "__return") then
				return Arguments
			end

			Remote:FireServer(NetworkInfo.ReturnToServer(...), "__return")

			NetworkInfo.ClientFunction(...)
		end)
	end

	return Remote
end


return Callbacks