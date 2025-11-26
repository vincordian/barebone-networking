export type NetworkInfo = {
	NetworkingDirection: "ClientToServer"|"ServerToClient"|"any", --Great if you don't want any accidents to happen
	
	Name: string, --Name of the remote
	
	ServerFunction: (any) -> (nil), --Fires when OnServerEvent ends
	ClientFunction: (any) -> (nil), --Fires when OnClientEvent ends
	
	ReturnToServer: (any) -> (any), --Fires when server fires the remote, the client fires to server back with data
	ReturnToClient: (any) -> (any), --Fires when client fires the remote, the server fires to client back with data
	
	AutoAddPlayers: boolean, --Will automatically add players left out to the target table if true
	
	Target: {Player}|nil, --Will fire all clients if nil
	
	Threads: {
		Server: {(any) -> (any)},--Secondary server functions basically
		Client: {(any) -> (any)}, --Secondary client functions basically


		ServerReturnThreads: {(any) -> (any)}, --Fires when client returns data
		ClientReturnThreads: {(any) -> (any)}, --Fires when server returns data
	}
}

return {}
