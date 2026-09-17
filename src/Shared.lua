-- Shared helpers used by more than one Global source module.
-- Keep subsystem-owned game logic in its owning module.

--Used to join a table of strings with translation brackets
JOIN_LANG_ORDER={"en", "ru", "zh-tw", "zh-cn", "ko", "es", "fr", "pt-br", "de"}
JOIN_LANG_TAGS={"{en}", "{ru}", "{zh-tw}", "{zh-cn}", "{ko}", "{es}", "{fr}", "{pt-br}", "{de}"}
joinLangParseCache={}
joinLangCacheCount=0
JOIN_LANG_CACHE_LIMIT=2048

function joinLangParse(text)
	local cached=joinLangParseCache[text]
	if cached~=nil then return cached end
	local firstStart, firstEnd, firstLang=text:find("{([%a%-]+)}", 1)
	if firstStart==nil then return text end
	local parsed={}
	local tagStart, tagEnd, lang=firstStart, firstEnd, firstLang
	while tagStart~=nil do
		local nextStart, nextEnd, nextLang=text:find("{([%a%-]+)}", tagEnd+1)
		parsed[lang]=text:sub(tagEnd+1, (nextStart or (#text+1))-1)
		tagStart, tagEnd, lang=nextStart, nextEnd, nextLang
	end
	if joinLangCacheCount>=JOIN_LANG_CACHE_LIMIT then joinLangParseCache={} joinLangCacheCount=0 end
	joinLangParseCache[text]=parsed
	joinLangCacheCount=joinLangCacheCount+1
	return parsed
end

--Join strings/numbers while preserving TTS translation tags. Tagged strings are parsed once and cached.
function joinLang(full_string)
	local parts={}
	for i=1, #full_string do parts[i]=joinLangParse(tostring(full_string[i])) end
	local output={}
	for langIndex, lang in ipairs(JOIN_LANG_ORDER) do
		output[#output+1]=JOIN_LANG_TAGS[langIndex]
		for i=1, #parts do
			local part=parts[i]
			if type(part)=="string" then output[#output+1]=part
			else
				local translated=part[lang] or part.en
				if translated~=nil then output[#output+1]=translated end
			end
		end
	end
	return table.concat(output)
end
