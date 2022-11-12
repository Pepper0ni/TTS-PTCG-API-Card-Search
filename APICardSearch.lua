lastSearchTime=os.time()
lastSearchText=false
lastSearchCount=false
lastSearchTotal=false
lastSearchFormat=false
curPos=0
curStart=1
lock=false
pageSizes={15,30,60,120,240}
scope=""

function onLoad(state)
 local params={
 function_owner=self,
 position={0,0,1.2},
 tooltip="Enter the term to search here.",
 label='Enter Card Name',
 font_size=197,
 width=1500,
 height=220,
 alignment=3,
 input_function="processReturn",
 font_color={0,0,0},
 scale={0.75,1,0.5},
 }
 self.createInput(params)
 if not state or state==""then
  pageSize=30
 else
  state=json.parse(state)
  pageSize=state.pageSize or 30
  scope=state.scope or""
  self.editInput({index=0,value=state.value or""})
  lastSearchText=state.text or false
  lastSearchCount=state.count or false
  lastSearchTotal=state.total or false
  lastSearchFormat=state.format or false
  curPos=state.pos or 0
 end
 setUpContextMenu()
 setUpButtons()
end

function setUpButtons()
 local params={
 function_owner=self,
 font_size=197,
 width=650,
 height=220,
 scale={0.75,1,0.5},
 }
 if scope=="strict" then params.color={0,1,0}else params.color={1,0,0}end
 butWrapper(params,{0.7,0,1.5},'Strict',"Toggles Strict search, searching only for the exact name.",'toggleStrict')

 if scope=="fuzzy" then params.color={0,1,0}else params.color={1,0,0}end
 butWrapper(params,{-0.35175,0,1.5},'Fuzzy',"Toggles Fuzzy Search, searching for anything containing the input.",'toggleFuzzy')

 params.color={1,1,1}
 params.width=200
 butWrapper(params,{-1.035,0,1.5},'é',"Place an é",'placeE')
 params.width=1500
 butWrapper(params,{0,0,1.8},'Search Standard',"Gets matching cards from Standard",'searchStandard')
 butWrapper(params,{0,0,2.1},'Search Expanded',"Gets matching cards from Expanded",'searchExpanded')
 butWrapper(params,{0,0,2.4},'Search All Cards',"Gets all matching cards.",'searchAll')
 if lastSearchCount then
  butWrapper(params,{0,0,2.7},"Get "..tostring(math.min(pageSize,lastSearchTotal-lastSearchCount)).." More","Get the next set of results.",'nextPage')
 end
end

function butWrapper(params,pos,label,tool,func)
 params.position=pos
 params.label=label
 params.tooltip=tool
 params.click_function=func
 self.createButton(params)
end

function toggleStrict()
 if scope=="strict"then scope=""else scope="strict"end
 self.clearButtons()
 setUpButtons()
 saveData()
end

function toggleFuzzy()
 if scope=="fuzzy"then scope=""else scope="fuzzy"end
 self.clearButtons()
 setUpButtons()
 saveData()
end

function placeE()
 self.editInput({index=0,value=self.getInputs()[1].value.."é"})
end

function searchStandard(obj,color,alt)
 search(' legalities.standard:Legal',color,self.getInputs()[1].value)
end

function searchExpanded(obj,color,alt)
 search(' legalities.expanded:Legal',color,self.getInputs()[1].value)
end

function searchAll(obj,color,alt)
 search("",color,self.getInputs()[1].value)
end

function nextPage(obj,color,alt)
 if lastSearchCount==false then
  broadcastToColor("No more results. Please start a new search",color,{1,0,0})
  self.clearButtons()
  setUpButtons()
 else
  getCards(lastSearchFormat,color,lastSearchText)
 end
end

function search(formatText,color,searchText)
 resetSearch()
 getCards(formatText,color,searchText)
end

function getCards(formatText,color,searchText)
 if os.difftime(os.time(),lastSearchTime)<1 then broadcastToColor("You can't search that fast.",color,{1,0,0})return end
 if lock then broadcastToColor("Already Searching...",color,{1,0,0})return end
 if searchText==""then broadcastToColor("Please enter a search term.",color,{1,0,0})return end
 lock=true
 decoded={}
 local strictText=""
 local fuzzyText=""
 if scope=="strict"then strictText="!"elseif scope=="fuzzy"then fuzzyText="*"end
 r=WebRequest.get('https://api.pokemontcg.io/v2/cards?q='..strictText..'name:"'..fuzzyText..searchText..fuzzyText..'"'..formatText..'&page='..tostring(curPos/pageSize+1)..'&pageSize='..tostring(pageSize).."&orderBy=set.releaseDate&select=id,name,images,number,rarity,set,supertype,subtypes,types,nationalPokedexNumbers",function()makeCards(r,color)end)
 lastSearchFormat=formatText
 lastSearchText=searchText
 curPos=curPos+pageSize
 lastSearchTime=os.time()
 saveData()
end

function makeCards(r,color)
 if r.is_error or r.response_code>=400 then
  log(r.error)
  log(r.text)
  log(r.response_code)
  broadcastToColor("Error: "..tostring(r.response_code),color,{1,0,0})
  resetSearch()
 else
  local decoded=json.parse(string.gsub(r.text,"\\u0026","&"))
  local spawnPos=self.positionToWorld({0,5.5,0})
  local spawnRot=self.getRotation()
  local spawnData={}
  local spawnLoc={posX=spawnPos[1],posY=spawnPos[2],posZ=spawnPos[3],rotX=spawnRot[1],rotY=spawnRot[2],rotZ=spawnRot[3],scaleX=1,scaleY=1,scaleZ=1}
  if decoded.count==1 then
   local cardData=decoded.data[1]
   spawnData=getCardData(spawnLoc,cardData,getCustomData(cardData),100000,1000)
  else
   spawnData={Name="Deck",
    Transform=spawnLoc,
    DeckIDs={},
    CustomDeck={},
    ContainedObjects={}
   }
   for a=1,#decoded.data do
    local cardData=decoded.data[a]
    local DeckID=999+a
    local customData=getCustomData(cardData)
    spawnData.DeckIDs[a]=DeckID*100
    spawnData.CustomDeck[DeckID]=customData
    spawnData.ContainedObjects[a]=getCardData(spawnLoc,cardData,customData,DeckID*100,DeckID)
    spawnData.ContainedObjects[a]["GUID"]=tostring(123456+a)
   end
  end
  spawnObjectData({data=spawnData})
  local curCount=(lastSearchCount or 0)+decoded.count
  if curCount>=decoded.totalCount then
   resetSearch()
  else
   lastSearchCount=curCount
   lastSearchTotal=decoded.totalCount
   self.clearButtons()
   setUpButtons()
  end
 end
 lock=false
 saveData()
end

function getCardData(spawnLoc,cardData,customData,cardID,deckID)
 local cardType=getSubTypeNum(cardData.subtypes)or subTypeNums[cardData.supertype]or 0
 local monType=enumTable(0,cardData.types,TypeNums,10,200)
 if monType==0 then monType=500 end
 local rar=""
 if cardData.rarity then
  rar=" "..string.gsub(cardData.rarity,"[^%u]","")
 end
 return{Name="CardCustom",
 Transform=spawnLoc,
 Nickname=cardData.name,
 Description=cardData.set.name.." #"..cardData.number..rar,
 GMNotes=tostring(cardType)..convertNatDex(cardData.nationalPokedexNumbers,cardData.subtypes),
 Memo=string.gsub(cardData.set.releaseDate,"/","")..buildCardNumber(cardData.number),
 CardID=cardID,
 CustomDeck={[deckID]=customData},
 LuaScriptState=tostring(monType)
}
end

function getCustomData(cardData)
 return{FaceURL=cardData.images.large.."?count="..cardData.number or"",
  BackURL="http://cloud-3.steamusercontent.com/ugc/809997459557414686/9ABD9158841F1167D295FD1295D7A597E03A7487/",
  NumWidth=1,
  NumHeight=1,
  BackIsHidden=true
 }
end

function buildCardNumber(cardNum)
 local numOnly=string.gsub(cardNum,"[^%d]","")
 if numOnly!=cardNum then
  local finalNum=(tonumber(numOnly)or 0)+500
  for c in cardNum:gmatch"[^%d]" do
   if c=="?"then c="}"end
   if c=="!"then c="{"end
   finalNum=string.byte(c)-65+finalNum
  end
  cardNum=tostring(finalNum)
 end
 while #cardNum<3 do cardNum="0"..cardNum end
 return cardNum
end

function resetSearch()
 lastSearchCount=false
 lastSearchText=false
 lastSearchTotal=false
 lastSearchFormat=false
 curPos=0
 self.clearButtons()
 setUpButtons()
end

function enumTable(enum,input,values,multi,extramulti)
 if input then
  for c=1,#input do
   if values[input[c]]then
    enum=enum+values[input[c]]*(1+multi)
    if multi==0 then enum=enum+extramulti else multi=0 end
   end
  end
 end
 return enum
end

function getSubTypeNum(subTypes)
 if subTypes then
  for c=1,#subTypes do
   if subTypeNums[subTypes[c]]then return subTypeNums[subTypes[c]]end
  end
 end
 return false
end

function convertNatDex(dexNums,subTypes)
 if dexNums then dexNum=dexNums[1]else return"0000000"end
 if natDexReplace[dexNum] then
  dexNum=natDexReplace[dexNum]
 else
  dexNum=tostring(dexNum*10)
  while #dexNum<5 do dexNum="0"..dexNum end
 end
 local monSubType=tostring(enumTable(0,subTypes,monSubTypeNums,0,0))
 while #monSubType<2 do monSubType="0"..monSubType end
 return dexNum..monSubType
end

function processReturn(obj,color,value,selected)
 local subedValue=string.gsub(value,"\n","")
 if subedValue!=value then
  Wait.frames(function()searchAll(obj,color,false)end,1)
 end
 saveData()
 return subedValue
end

function setUpContextMenu()
 for c=1,#pageSizes do
  if pageSize!=pageSizes[c]then
   self.addContextMenuItem("Page Size: "..tostring(pageSizes[c]),function()changePageSize(pageSizes[c])end)
  end
 end
 self.addContextMenuItem("Release Lock",function()lock=false end)
end

function changePageSize(size)
 pageSize=size
 saveData()
 self.clearContextMenu()
 setUpContextMenu()
 self.clearButtons()
 setUpButtons()
end

function saveData()
 self.script_state=json.serialize({pageSize=pageSize,scope=scope,value=self.getInputs()[1].value,text=lastSearchText,total=lastSearchTotal,count=lastSearchCount,format=lastSearchFormat,pos=curPos})
end

subTypeNums={
 ["Trainer"]=3,
 ["Supporter"]=4,
 ["Stadium"]=5,
 ["Pokémon Tool"]=6,
 ["Technical Machine"]=6,
 ["Special"]=8,
 ["Energy"]=9
}

TypeNums={
 Grass=1,
 Fire=2,
 Water=3,
 Lightning=4,
 Psychic=5,
 Fighting=6,
 Darkness=7,
 Metal=8,
 Fairy=9,
 Dragon=10,
 Colorless=11,
}

monSubTypeNums={
 ["Level-Up"]=1,
 BREAK=2,
 EX=3,
 MEGA=1,
 GX=5,
 ["TAG TEAM"]=1,
 SP=7,
 LEGEND=9,
 V=10,
 VMAX=11,
 VSTAR=12,
}

natDexReplace={
 [172]="00245",
 [173]="00345",
 [174]="00385",
 [169]="00425",
 [182]="00455",
 [863]="00535",
 [186]="00625",
 [199]="00805",
 [462]="00823",
 [865]="00827",
 [208]="00955",
 [236]="01055",
 [237]="01075",
 [463]="01085",
 [464]="01123",
 [440]="01127",
 [242]="01135",
 [465]="01145",
 [230]="01175",
 [439]="01215",
 [866]="01225",
 [212]="01233",
 [238]="01237",
 [239]="01245",
 [466]="01253",
 [240]="01257",
 [467]="01265",
 [196]="01361",
 [197]="01362",
 [470]="01363",
 [471]="01364",
 [700]="01365",
 [233]="01373",
 [474]="01377",
 [446]="01425",
 [468]="01765",
 [298]="01825",
 [438]="01845",
 [424]="01905",
 [469]="01935",
 [430]="01985",
 [429]="02005",
 [360]="02015",
 [472]="02075",
 [461]="02155",
 [473]="02215",
 [864]="02225",
 [458]="02255",
 [862]="02645",
 [475]="02825",
 [476]="02995",
 [406]="03145",
 [407]="03155",
 [477]="03565",
 [433]="03575",
 [478]="03625",
 [867]="05635",
 [899]="02345",
 [900]="01237",
 [901]="02175",
 [902]="05505",
 [903]="02157",
 [904]="02115",
}
