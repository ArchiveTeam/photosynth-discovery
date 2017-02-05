function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end


-- if tabl passed then write results to this table
function findGuids(filetext, tabl)
	local list = tabl or {}
	for guid in filetext:gmatch("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") do
		list[guid] = true
	end
	
	return list
end

function findUsers(filetext, tabl)
	local list = tabl or {}
	for name in filetext:gmatch("\"OwnerUsername\"%:\"([0-9a-zA-Z%-%_]+)\"") do
		list[name] = true
	end
	
	return list
end

function findTotalResults(filetext)
	local text = filetext:sub(1, 40)
	-- 
	local result = text:match("\"TotalResults\"%:(%d+),")

	return tonumber(result) or 0
end

function createSubJob(totalResults, searchTerm)
	local URLTable = {}

	local numRows = 100
	local filter = "All"
	local maxIter = math.min(100000, totalResults)
	
	io.stdout:write("[INFO] Creating subjob for '".. searchTerm .."' with '".. maxIter .."' items\n")
	io.stdout:flush()
	
	if totalResults > maxIter then
		if totalResults < maxIter*2 then
			-- additional grab message
			io.stdout:write("[INFO] Need additional grab for search term ".. searchTerm, "\n")
			io.stdout:flush()
		else -- deploy heavy guns message
			io.stdout:write("[INFO] DEPLOYING HEAVY GUNS on search term ".. searchTerm, "\n")
			io.stdout:flush()
		end
	end
	
	for i = 0, maxIter, numRows do
		table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=2&orderby=0")
	-- &sortby =
	--	0 = BestMatch -- doesn't seem to work with ORDERBY, returns the same as without params
	--	1 = BestSynth
	--	2 = DateAdded
	--	3 = NumberOfViews
	--	4 = CreatedBy
	-- &orderby = 
	--	0 = Descending (date: start with fresh)
	--	1 = Ascending (date: start with old)
	
		-- do we have more items than the limit?
		-- filter out insane amount of results (totalResults < 1800000)
		if totalResults > maxIter then
			-- introduce more URLs with SortBy + OrderBy function
			
			-- if nItems < limit*2 than the reverse order is enough
			-- and only grab as many from the end as we need
			if totalResults < maxIter*2 and (totalResults - maxIter) <= i then
				--print("->  Need additional grab!")
				
				-- reverse Date
				table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=2&orderby=1")
			else -- deploy HEAVY GUNS

				-- reverse Date
				table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=2&orderby=1")
				-- BestMatch
				table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=0&orderby=0")
				
				for n = 0, 1 do
					-- BestSynth
					table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=1&orderby=".. n)
					-- Views
					table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=3&orderby=".. n)
					-- CreatedBy
					table.insert(URLTable, "https://photosynth.net/rest/v1.0/search/?q=".. searchTerm .."&collectionTypeFilter=".. filter .. "&numRows=".. numRows .."&offset=".. i .."&sortby=4&orderby=".. n)
				end
			end
			
		end
	end
	
	return URLTable
end

function createSubJobGeo(totalResults, wlon)
	local URLTable = {}
	
	local restURL = "https://photosynth.net/rest/v1.0/search/bbox/"
	local numRows = 100
	local filter = "All"
	local maxIter = math.min(100000, totalResults)
	
	io.stdout:write("[INFO] Creating subjob for longitude '".. wlon .."' with '".. maxIter .."' items\n")
	io.stdout:flush()
	
	if totalResults > maxIter then
		if totalResults > maxIter then
			-- additional grab message
			io.stdout:write("[INFO] Need additional grab for longitude ".. wlon, "\n")
			io.stdout:flush()
		end
	end
	
	-- slat=-90  wlon=-47  nlat=90  elon=-46
	for i = 0, maxIter, numRows do
		
		-- do we have less items than the limit?
		if totalResults <= maxIter then
			table.insert(URLTable, restURL.."?collectionTypeFilter=".. filter .. "&slat=-90".."&wlon="..wlon.."&nlat=90".."&elon="..(wlon+1).."&numRows=".. numRows .."&offset=".. i)
		else
			io.stdout:write("totalResults is bigger than maxIter: ".. totalResults .." < ".. maxIter, "\n")
			io.stdout:flush()
			--[[
			-- introduce more URLs
			local step = 0.1
			for lat = -60, (0-step), step do
				table.insert(URLTable, restURL.."?collectionTypeFilter=".. filter .. "&slat=".. lat .."&wlon="..wlon.."&nlat=".. (lat+step) .."&elon="..(wlon+1).."&numRows=".. numRows .."&offset=".. i)
			end
			for lat = 0, (75-step), step do
				table.insert(URLTable, restURL.."?collectionTypeFilter=".. filter .. "&slat=".. lat .."&wlon="..wlon.."&nlat=".. (lat+step) .."&elon="..(wlon+1).."&numRows=".. numRows .."&offset=".. i)
			end
			]]
		end
	end
	
	return URLTable
end

function createSubJobCustom(totalResults, url)
	local URLTable = {}
	
	--local restURL = "https://photosynth.net/rest/v1.0/search/bbox/"
	local numRows = 100
	--local filter = "All"
	local maxIter = math.min(100000, totalResults)
	
	io.stdout:write("[INFO] Creating custom subjob for ".. url .."\n")
	io.stdout:flush()
	
	if totalResults > maxIter then
		if totalResults > maxIter then
			-- additional grab message
			io.stdout:write("[INFO] Need additional grab!", "\n")
			io.stdout:flush()
		end
	end
	
	for i = 0, maxIter, numRows do
		
		-- do we have less items than the limit?
		if totalResults <= maxIter then
			local URLText = string.gsub(url, "&offset=%d+", "&offset=".. i)
			table.insert(URLTable, URLText)
		else
			io.stdout:write("[ERR] totalResults is bigger than maxIter: ".. totalResults .." < ".. maxIter, "\n")
			io.stdout:flush()
		end
	end
	
	return URLTable
end