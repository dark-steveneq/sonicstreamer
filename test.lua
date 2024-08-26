-- VERSION     = "test.lua v1.0",
-- DESCRIPTION = "SonicStreamer API tester",
-- URL         = "https://github.com/dark-steveneq/sonicstreamer",
-- LICENSE     =
--         FUCK AROUND and FIND OUT PUBLIC LICENSE
--                 Version 2, August 2023

-- Copyright (C) 2024 Dark Steveneq <dark.steveneq@outlook.com>

-- Everyone is permitted to copy and distribute verbatim or modified
-- copies of this license document, and changing it is allowed as long
-- as the name is changed.

--             FUCK AROUND and FIND OUT PUBLIC LICENSE
-- TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

-- 0. YOU MUST INCLUDE THE ABOVE COPYRIGHT NOTICE IN ALL COPIES, REDISTRIBUTIONS, OR MODIFICATIONS OF THE SOFTWARE
-- 1. DON'T BLAME ME FOR ANY SHIT
-- 2. else, You just DO WHAT THE FUCK YOU WANT TO.

-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY,FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
-- HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, redistribution
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
-- THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local subsonic = require("subsonic")
local speaker = peripheral.find("speaker")
if not speaker then
    error("Speaker is required", 0)
end

if subsonic.login(settings.get("bsp.instance"), settings.get("bsp.user"), settings.get("bsp.password")) then
    print("Login succeded")
else
    error("Login failed!", 0)
end

local albums = subsonic.getPlaylists()
print("Found playlists: " .. #albums)
if #albums == 0 then
    error("", 0)
end
local album = albums[2]
print("Using playlist " .. album.name)
local song = subsonic.getPlaylistSongs(album)[1]
print("Using song " .. song.name)
local playback = subsonic.playSong(song, speaker)
if not playback then
    error("Couldn't initialize playback!", 0)
end
print("Playback initialized")
print("A - Skip 10 secs left")
print("S - Toggle playback")
print("D - Skip 10 secs right")
parallel.waitForAny(function()
    playback:PlayThread()
end, function()
    while not playback.exit and playback.playtime < playback.length do
        local _, character = os.pullEvent("char")
        if character == "s" then
            playback:Toggle()
        elseif character == "a" then
            playback:Skip(playback.playtime - 10)
            print("Skipping left", playback.playtime)
        elseif character == "d" then
            playback:Skip(playback.playtime + 10)
            print("Skipping right", playback.playtime)
        end
    end
end)