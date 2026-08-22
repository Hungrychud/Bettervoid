-- BetterVoid obfuscated loader (Matcha)
-- Paste into Matcha: reads the local workspace file, no HttpGet.
local p='Bet'..'ter'  local q='Void/'
local r='loa'..'der'  local s='.'..'lua'
local path=p..q..r..s
local fn=getfenv()
local rf='read'..'file'  local ld='load'..'string'
local src=fn[rf](path)
fn[ld](src)()
