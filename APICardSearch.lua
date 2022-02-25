lastSearchTime=os.time()

function onLoad(state)
 pageSize=state or"30"
 setUpContextMenu()
 curPage=1
 local selfScale=self.getScale()
 local params={
 function_owner=self,
 position={0,0,1.2},
 tooltip="Enter the term to search here.",
 label='Enter Card Name',
 font_size=180,
 width=1500,
 height=220,
 alignment=3,
 input_function="processReturn",
 font_color={0,0,0},
 scale={1/selfScale.x,1/selfScale.y,1/selfScale.z},
 }
 self.createInput(params)

 local params={
 function_owner=self,
 label='Strict',
 tooltip="Toggles Strict search, searching only for the exact name. Highly reccomended when searching for N.",
 font_size=180,
 width=750,
 height=220,
 scale={1/selfScale.x,1/selfScale.y,1/selfScale.z},
 position={0.6,0,1.5},
 click_function='toggleStrict'
 }
 if not strict then params.color={1,0,0} else params.color={0,1,0} end
 self.createButton(params)
 params.color={1,1,1}

 params.position[1]=-0.6
 params.label='é'
 params.tooltip="Place an é"
 params.click_function='placeE'
 self.createButton(params)

 params.position={0,0,1.8}
 params.width=1500
 params.label='Search Standard'
 params.tooltip="Gets matching cards from Standard"
 params.click_function='searchStandard'
 self.createButton(params)

 params.position[3]=2.1
 params.label='Search Expanded'
 params.tooltip="Gets matching cards from Expanded"
 params.click_function='searchExpanded'
 self.createButton(params)

 params.position[3]=2.4
 params.label='Search All Cards'
 params.tooltip="Gets all matching cards."
 params.click_function='searchAll'
 self.createButton(params)

 params.position[3]=2.7
 params.label='Get Next Page'
 params.tooltip="Get the next set of results, if any."
 params.click_function='nextPage'
 self.createButton(params)
end

function toggleStrict()
 if not strict then strict=true else strict=false end
 local color={0,1,0}
 if not strict then color={1,0,0} end
 self.editButton({index=0,color=color})
end

function placeE()
 self.editInput({index=0,value=self.getInputs()[1].value.."é"})
end

function searchStandard(obj,color,alt)
 search(' legalities.standard:Legal',color,1)
end

function searchExpanded(obj,color,alt)
 search(' legalities.expanded:Legal',color,1)
end

function searchAll(obj,color,alt)
 search("",color,1)
end

function nextPage(obj,color,alt)
 if lastSearch==false then
  broadcastToColor("No more results. Please start a new search",color,{1,0,0})
 elseif not lastSearch then
  broadcastToColor("Please start a search before getting a new page.",color,{1,0,0})
 else
  search(lastSearch,color,curPage)
 end
end

function search(formatText,color,page)
 if os.difftime(os.time(),lastSearchTime)<1 then broadcastToColor("You can't search that fast.",color,{1,0,0})return end
 lastSearch=formatText
 curPage=page+1
 decoded={}
 local strictText=""
 if strict then strictText="!"end
 r=WebRequest.get('https://api.pokemontcg.io/v2/cards?q='..strictText..'name:"'..self.getInputs()[1].value..'"'..formatText..'&page='..page..'&pageSize='..pageSize.."&orderBy=set.releaseDate",function()makeCards(r,color)end)
 lastSearchTime=os.time()
end

function makeCards(r,color)
 if r.is_error or r.response_code>=400 then
  log(r.error)
  log(r.text)
  log(r.response_code)
  broadcastToColor("Error: "..tostring(r.response_code),color,{1,0,0})
  lastSearch=nil
 else
  local decoded=json.parse(string.gsub(r.text,"\\u0026","&"))
  if decoded.count<tonumber(pageSize) then lastSearch=false end
  local spawnPos=self.positionToWorld({0,5.5,0})
  local spawnRot=self.getRotation()
  local spawnData={}
  local spawnLoc={posX=spawnPos[1],posY=spawnPos[2],posZ=spawnPos[3],rotX=spawnRot[1],rotY=spawnRot[2],rotZ=spawnRot[3],scaleX=1,scaleY=1,scaleZ=1}
  if decoded.count==1 then
   local cardData=decoded.data[1]
   local customData={
    FaceURL=cardData.images.large.."?count="..cardData.number or"",
    BackURL="http://cloud-3.steamusercontent.com/ugc/809997459557414686/9ABD9158841F1167D295FD1295D7A597E03A7487/",
    NumWidth=1,
    NumHeight=1,
    BackIsHidden=true
   }
   spawnData=
   {Name="CardCustom",
    Transform=spawnLoc,
    Nickname=cardData.name,
    Description=cardData.set.name.." #"..cardData.number,
    GMNotes=enumTypes(cardData.supertype,cardData.subtypes)..convertNatDex(cardData.nationalPokedexNumbers)or"",
    Memo=string.gsub(cardData.set.releaseDate,"/","")..string.gsub(cardData.number,"[^%d]",""),
    CardID=100000,
    CustomDeck={[1000]=customData}
   }
  else
   spawnData=
    {Name="Deck",
    Transform=spawnLoc,
    DeckIDs={},
    CustomDeck={},
    ContainedObjects={}
   }
   for a=1,#decoded.data do
    local cardData=decoded.data[a]
    local DeckID=999+a
    local customData={
     FaceURL=cardData.images.large.."?count="..cardData.number or"",
     BackURL="http://cloud-3.steamusercontent.com/ugc/809997459557414686/9ABD9158841F1167D295FD1295D7A597E03A7487/",
     NumWidth=1,
     NumHeight=1,
     BackIsHidden=true
    }
    spawnData.DeckIDs[a]=DeckID*100
    spawnData.CustomDeck[DeckID]=customData
    spawnData.ContainedObjects[a]={
     Name="CardCustom",
     GUID=tostring(123456+a),
     Transform=spawnLoc,
     Nickname=cardData.name,
     Description=cardData.set.name.." #"..cardData.number,
     GMNotes=enumTypes(cardData.supertype,cardData.subtypes)..convertNatDex(cardData.nationalPokedexNumbers)or"",
     Memo=string.gsub(cardData.set.releaseDate,"/","")..string.gsub(cardData.number,"[^%d]",""),
     CardID=DeckID*100,
     CustomDeck={[DeckID]=customData}
    }
    a=a+1
   end
  end
  spawnObjectData({data=spawnData})
 end
end

function enumTypes(Type,subTypes)
 local enum=TypeNums[Type]or 0
 if subTypes then
  for c=1,#subTypes do
   enum=enum+(TypeNums[subTypes[c]]or 0)
  end
 end
 return tostring(enum)
end

function convertNatDex(dexNums)
 if dexNums then dexNum=dexNums[1]else return "00000" end
 if natDexReplace[dexNum] then return natDexReplace[dexNum] end
 dexNum = tostring(dexNum*10)
 while #dexNum<5 do dexNum="0"..dexNum end
 return dexNum
end

function processReturn(obj,color,value,selected)
 local subedValue=string.gsub(value,"\n","")
 if subedValue!=value then
  Wait.frames(function()searchAll(obj,color,false)end,1)
 end
 return subedValue
end

function setUpContextMenu()
 if pageSize!="20" then
  self.addContextMenuItem("Page Size: 20",function()changePageSize("20")end)
 end
 if pageSize!="30" then
  self.addContextMenuItem("Page Size: 30",function()changePageSize("30")end)
 end
 if pageSize!="50" then
  self.addContextMenuItem("Page Size: 50",function()changePageSize("50")end)
 end
 if pageSize!="100" then
  self.addContextMenuItem("Page Size: 100",function()changePageSize("100")end)
 end
 if pageSize!="250" then
  self.addContextMenuItem("Page Size: 250",function()changePageSize("250")end)
 end
end

function changePageSize(size)
 pageSize=size
 self.script_state=size
 self.clearContextMenu()
 setUpContextMenu()
end

TypeNums={
 ["Trainer"]=3,
 ["Energy"]=7,
 ["Supporter"]=1,
 ["Stadium"]=2,
 ["Pokémon Tool"]=3,
 ["Special"]=1,
 ["Level-Up"]=1,
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
 [902]="02157",
}
