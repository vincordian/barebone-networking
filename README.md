For the scallywags using my code:

Use Network.new, you can omit the parenthesis like:
Network.new {
Name = "Test"
ClientFunction = function()
  print("Hello World")
end
}

Networks with the same name will hook up to eachother, this is how the client & server communicate.

Setup the server within 5 seconds of the client, that's the threshold to stop WaitForChild, you can edit this. 
