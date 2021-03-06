class("MeshRequester" , OBJLoader)

function OBJLoader.MeshRequester:__init(args , playerA , callback , callbackInstance)
	self.modelPath = args.path
	self.type = args.type or OBJLoader.Type.Single
	self.is2D = args.is2D or false
	self.callbacks = {}
	self.models = {}
	self.depths = {}
	self.modelCount = 0
	self.isFinished = false
	self.result = nil
	self.playerA = playerA


	self:AddCallback(callback , callbackInstance)
	
	if self.is2D == false and self.type == OBJLoader.Type.MultipleDepthSorted then
		error("[OBJLoader] Cannot be 3D and MultipleDepthSorted!")
	end
	
	-- Debug: print("Sending request to server")
	Network:Send("OBJLoaderRequest" , {path = self.modelPath, player = playerA})

	self.sub = Network:Subscribe("OBJLoaderReceive" , self , self.Receive)


end

function print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

function OBJLoader.MeshRequester:Receive(args)
	if args.modelPath ~= self.modelPath then
		-- Debug: print("Model path invalid.")
		return
	end
	
	self.PlayerA = args.player
	--print("cMeshRequester received server mesh for " .. args.playerTarget:GetName())

	Network:Unsubscribe(self.sub)
	


	local modelData = args.modelData
	
	-- Create the Models from the models. The choice of variable names wasn't well thought out...
	for modelName , mesh in pairs(modelData.meshes) do
		vertices = {}
		local depthsBuffer = 0
		-- Convert the mesh into a table of vertices, which will be turned into a Model.
		for index , triangleData in ipairs(mesh.triangleData) do
			local color = modelData.colors[triangleData[4]]
			if self.is2D then
				local vert1 = modelData.vertices[triangleData[1]]
				local vert2 = modelData.vertices[triangleData[2]]
				local vert3 = modelData.vertices[triangleData[3]]
				table.insert(vertices , Vertex(Vector2(vert1.x , vert1.z) , color))
				table.insert(vertices , Vertex(Vector2(vert2.x , vert2.z) , color))
				table.insert(vertices , Vertex(Vector2(vert3.x , vert3.z) , color))
				
				if self.type == OBJLoader.Type.MultipleDepthSorted then
					depthsBuffer = depthsBuffer + vert1.y + vert2.y + vert3.y
				end
			else
				local vert1 = modelData.vertices[triangleData[1]]
				local vert2 = modelData.vertices[triangleData[2]]
				local vert3 = modelData.vertices[triangleData[3]]
				table.insert(vertices , Vertex(vert1 , color))
				table.insert(vertices , Vertex(vert2 , color))
				table.insert(vertices , Vertex(vert3 , color))
			end
		end
		

		local model = Model.Create(vertices)
		model:SetTopology(Topology.TriangleList)
		model:Set2D(self.is2D)
		
		if self.type == OBJLoader.Type.Multiple then
			self.models[modelName] = model
		else
			table.insert(self.models , model)
		end
		
		if self.type == OBJLoader.Type.MultipleDepthSorted then
			local averageZ = depthsBuffer / #vertices
			table.insert(self.depths , averageZ)
		end
		
		self.modelCount = self.modelCount + 1
	end
	
	if self.type == OBJLoader.Type.MultipleDepthSorted then
		local buffer = {}
		for index , model in ipairs(self.models) do
			local info = {
				model = model ,
				depth = self.depths[index]
			}
			table.insert(buffer , info)
		end
		
		local SortByDepth = function(a , b)
			return a.depth < b.depth
		end
		table.sort(buffer , SortByDepth)
		
		self.models = {}
		for index , t in ipairs(buffer) do
			table.insert(self.models , t.model)
		end
	end
	
	if self.type == OBJLoader.Type.Single then
		if self.modelCount > 1 then
			warn("[OBJLoader] Type is Single but there are "..self.modelCount.." meshes!")
		end
		
		for modelName , model in pairs(self.models) do
			self.result = model
			break
		end
	elseif self.type == OBJLoader.Type.Multiple then
		self.result = self.models
	elseif self.type == OBJLoader.Type.MultipleDepthSorted then
		self.result = self.models
	end

	self.result = vertices
	
	for index , callback in ipairs(self.callbacks) do
		self:ForceCallback(callback.func , callback.instance)
	end
	
	self.isFinished = true
end

function OBJLoader.MeshRequester:AddCallback(func , instance)
	table.insert(self.callbacks , {func = func , instance = instance})
end

function OBJLoader.MeshRequester:ForceCallback(func , instance)
	if instance then
		func(instance , self.result , self.modelPath, self.playerA)
	else
		--print("Calling back for player !!!!! " .. self.playerA:GetName())
		func(self.result , self.modelPath, self.playerA)
	end
end
