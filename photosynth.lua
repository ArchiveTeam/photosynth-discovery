dofile("urlcode.lua")
dofile("table_show.lua")
dofile("photosynth-func.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local downloaded = {}
local addedtolist = {}

local guids = {}
local stringsearch = {}
local geosearch = {}
local usersearch = {}

local newquestions = {}
local newusers = {}

local newGuidList = {}
local newUserList = {}

-- URL blacklist
for ignore in io.lines("ignore-list", "r") do
	downloaded[ignore] = true
end

-- Add items from ENV
if item_type == "stringsearch" then
	for jobitem in string.gmatch(item_value, "([^,]+)") do
		stringsearch[jobitem] = true
	end
	
elseif item_type == "geosearch" then
	-- local disco by vad
	--[[

	-- https://photosynth.net/rest/v1.0/search/bbox/compact?collectionTypeFilter=All&slat=-90&wlon=-180&nlat=90&elon=180&numRows=1000&offset=0

	local file = assert(io.open("geo-urls.txt", "wb"))

	for i = -180, 179, 1 do
		print(i,i+1, -90, 90)
		file:write("https://photosynth.net/rest/v1.0/search/bbox/compact?collectionTypeFilter=All&slat=-90&wlon=".. i .."&nlat=90&elon=".. i+1 .."&numRows=1000&offset=0", "\n")
	end
	]]
elseif item_type == "discovery" then
	
else
	io.stdout:write("ERROR! Unknown item type: ".. item_type)
	io.stdout:write("Exiting...")
	io.stdout:flush()
	os.execute("sleep 3")
	os.exit(1)	-- is it okay to do inside wget-lua?
end

read_file = function(file)
	if file then
		local f = assert(io.open(file))
		local data = f:read("*all")
		f:close()
		return data
	else
		return ""
	end
end

-- URLs to synths should be like this:
-- https://photosynth.net/view/1e509490-5657-453d-a2f6-2e55d14ae512
-- to trigger redirection 302 to view.aspx?cid= ...

-- Separate job: forum.aspx
photosynthDiscoWhitelist = {
"^https?://photosynth.net/userprofilepage.aspx%?user=",
"^https?://photosynth%.net/rest/v1%.0/",

}

-- RSS feed?
photosynthDiscoBlacklist = {
'https?://photosynth.net/explore.aspx',
"https?://photosynth.net/join.aspx",
"https?://photosynth.net/create.aspx",
"https?://photosynth.net/about.aspx",
"https?://photosynth.net/help.aspx",
"https?://photosynth.net/ice.aspx",
"https?://photosynth.net/search.aspx",

"https?://photosynth.net/preview/about",
"https?://photosynth.net/preview/upload",

"http://cdn1.ps1.photosynth.net/installer/2014-08-07/PhotosynthInstall.exe",


"^https?://login.live.com/login.srf",
"^https?://photosynth.net/view.aspx%?cid=.*",
"bing%.com/",
"msn%.com/",
"microsoft%.com/",

}

-- return:
-- TRUE - will be added to queue
-- FALSE - will not be added
allowed = function(url)
	-- add newusers/newquestions, if found, to the table
  
	for i = 1, #photosynthDiscoWhitelist do
		if string.find(url, photosynthDiscoWhitelist[i]) then
			print("+++ ".. url:sub(1, 80))
			return true
		end
	end
	
	for i = 1, #photosynthDiscoBlacklist do
		if string.find(url, photosynthDiscoBlacklist[i]) then
			print("--- ".. url:sub(1, 80))
			return false
		end
	end
	
	return false
end

function addedtolistAdd(url)
	addedtolist[url] = true
end

function isAdded(url)
	if downloaded[url] or addedtolist[url] then
		return true
	end
end

-- Custom Accept/Rejection rules
wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
	local url = urlpos["url"]["url"]
	local html = urlpos["link_expect_html"]

	if (downloaded[url] ~= true and addedtolist[url] ~= true) and (allowed(url) or html == 0) then
		
		addedtolist[url] = true
		return true
		
	else
		return false
	end
end

-- Called on URL extraction from file
wget.callbacks.get_urls = function(file, url, is_css, iri)
	downloaded[url] = true
	
	local urls = {}
	local html = nil
	local fileText
	
	if url:find("https://photosynth.net/", 1, true) then
		io.stdout:write("Checking for GUIDs+Users: ", url, "\n")
		io.stdout:flush()
		if not fileText then fileText = read_file(file) end
		findGuids(fileText, newGuidList)
		findUsers(fileText, newUserList)
	end
	
	-- stringsearch component
	if url:find("https://photosynth.net/rest/v1.0/search/?q=", 1, true) then
		if not fileText then fileText = read_file(file) end
		
		--findGuids(fileText, newGuidList)
		--findUsers(fileText, newUserList)
		
		-- is offset==0?
		if isAdded(url) == false and tonumber(url:match("https://photosynth%.net/rest/v1%.0/search/%?q=.-&offset=(%d+).*")) == 0 then
			-- we grabbed the first page, see how many results there are and generate urls
			
			
			local totalResults = findTotalResults(fileText)
			local searchTerm = tostring(url:match("%?q%=(.-)%&") or url:match("%?q%=(.+)"))
			
			if totalResults ~= 0 and searchTerm ~= "nil" then
				if totalResults > 1 then
					-- return generated URLs
					local URLList = createSubJob(totalResults, searchTerm)
					
					for i = 1, #URLList do
						addedtolistAdd(URLList[i])
						table.insert(urls, {url = URLList[i]})
					end
					
					io.stdout:write("[INFO] ".. #URLList .." URLs added to queue!", "\n")
					io.stdout:flush()
					
				elseif totalResults == 1 then
					--findGuids(fileText, newGuidList)
					--findUsers(fileText, newUserList)
				else
					io.stdout:write("[INFO] 0 Results for searchTerm ".. searchTerm, "\n")
					io.stdout:flush()
				end
			else
				io.stdout:write("[WARNING] NO RESULTS FOUND for searchTerm ".. searchTerm, "\n")
				io.stdout:flush()
			end
		end
	end
	
	-- geosearch component
	-- "https://photosynth.net/rest/v1.0/search/bbox/compact" allows up to numRows=1000
	-- non-compact allows max 100
	if url:find("https://photosynth.net/rest/v1.0/search/bbox/", 1, true) then
		--local fileText = read_file(file)
		
		--findGuids(fileText, newGuidList)
		--findUsers(fileText, newUserList)
		
		-- is offset==0?
		if isAdded(url) == false and tonumber(url:match("https://photosynth.net/rest/v1.0/search/bbox/%?.-&offset=(%d+).*")) == 0 then
			
			if not fileText then fileText = read_file(file) end
			local totalResults = findTotalResults(fileText)
			local numRows = tonumber(url:match("numRows=(%d+)"))
			
			if totalResults > numRows then
				local wlon = url:match("&wlon=([%-%+%d%.]+)")
				
				local URLList = createSubJobGeo(totalResults, wlon)
				
				for i = 1, #URLList do
					addedtolistAdd(URLList[i])
					table.insert(urls, {url = URLList[i]})
				end
				
				io.stdout:write("[INFO] ".. #URLList .." geo-URLs added to queue!", "\n")
				io.stdout:flush()
			end
			
		end
	
	end
	
	-- usersearch component
	if isAdded(url) == false and url:find("https://photosynth.net/userprofilepage.aspx?user=", 1, true) then
		local username = url:match("%??user=(.+)")
		
		--local fileText = read_file(file)
		
		--findGuids(fileText, newGuidList)
		--findUsers(fileText, newUserList)
		
		table.insert(urls, {url = "https://photosynth.net/rest/v1.0/users/".. username .."/favorites?numRows=100&offset=0"})
		-- user stats for public and unlisted synths
		table.insert(urls, {url = "https://photosynth.net/rest/v1.0/users/".. username .."/"})
	end
	
	-- if user favorite page
	if isAdded(url) == false and url:match("https://photosynth.net/rest/v1.0/users/.-/favorites") then
		
		
		--findGuids(fileText, newGuidList)
		--findUsers(fileText, newUserList)
		
		--if offset=0
		if tonumber(url:match("https://photosynth.net/rest/v1.0/users/.-/favorites?numRows=%d+&offset=(%d+)")) == 0 then
			
			if not fileText then fileText = read_file(file) end
			local totalResults = findTotalResults(fileText)
			local numRows = tonumber(url:match("numRows=(%d+)"))
			
			if totalResults > numRows then
				local URLList = createSubJobCustom(totalResults, url)
				
				for i = 1, #URLList do
					addedtolistAdd(URLList[i])
					table.insert(urls, {url = URLList[i]})
				end
				
				io.stdout:write("[INFO] ".. #URLList .." favorite URLs added to queue!", "\n")
				io.stdout:flush()
			end
		end
	end
	--
	
	-- GUID component
	-- /view/{id}	-- only add the rest if this one doesn't fail
	-- /media/{id}
	-- /media/{id}/tags
	-- /media/{id}/comments
	-- /media/{id}/annotations
	-- /tags/{tag}/media -- discover more photosynths
	return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. " \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"]) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0.3

  if sleep_time > 0.01 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

-- NOT WARRIOR COMPLIANT: FILE NAMES
wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local fileguid = io.open(item_dir..'/'..warc_file_base..'_geoguid.txt', 'wb')
  
  for guid, _ in pairs(newGuidList) do
    fileguid:write("guid:" .. guid .. "\n")
  end
  
  local fileuser = io.open(item_dir..'/'..warc_file_base..'_geouser.txt', 'wb')
  for user, _ in pairs(newUserList) do
    fileuser:write("user:" .. user .. "\n")
  end
  
  fileguid:close()
  fileuser:close()
end
