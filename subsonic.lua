-- VERSION     = "subsonic.lua v1.0",
-- DESCRIPTION = "Subsonic API implementation for SonicStreamer",
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

-- Libraries
local md5 = require("md5")
local dfpwm = require("cc.audio.dfpwm")

local Subsonic = {}

-- Private variables
local Instance
local User
local Password



local decodeCount = 4800 / 8
---Playback Class responsile for controlling music playback.
local classPlayback = {
    raw = "",         -- Unprocessed chunks
    decoded = {},     -- Decoded chunks
    decoder = nil,    -- Decoder
    jitDecode = true, -- Whether to decode during playback or not
    playtime = 1,     -- Current playtime
    length = 0,       -- Length of the song
    speakers = {},    -- Speakers to play on
    volume = 1,       -- Volume to play on
    playing = true,   -- Whether the song is playing or not
    exit = false      -- Set to true if you want to kill PlayThread()
}



---Play song from chunks
---@param chunks string Read DFPWM file
---@param speakers ccTweaked.peripherals.Speaker[] Speakers to play on
---@return Playback playback Class instance
function classPlayback:New(chunks, speakers)
    local o = {
        raw = chunks,
        length = #chunks / decodeCount,
        speakers = speakers,
        decoder = dfpwm.make_decoder()
    }
    setmetatable(o, self)
    self.__index = self
    return o
end



---Decode current or other chunk.
---@param index number|nil Chunk index to decode
---@return boolean completed Whether the decode succeded or not
function classPlayback:Decode(index)
    if index == nil then
        index = self.playtime
    end
    local chunk = self.raw:sub((index - 1) * decodeCount + 1, index * decodeCount)
    if not chunk or self.decoded[index] then
        return false
    end
    self.decoded[index] = dfpwm.decode(chunk)
    return true
end



---Play current chunk.
---@return boolean completed Whether the playback succeded or not
function classPlayback:PlaySingle()
    if not self.playing or self.playtime < self.length then
        self.playing = false
        return false
    elseif not self.decoded[self.playtime] then
        if self.jitDecode then
            self:Decode()
        else
            return false
        end
    end
    local decoded = self.decoded[self.playtime]
    local volume = self.volume
    for _, speaker in pairs(self.speakers) do
        speaker.playAudio(decoded, volume)
    end
    if self.jitDecode then
        self:Decode(self.playtime + 1)
    end
    os.pullEvent("speaker_audio_empty")
    self.playtime = self.playtime + 1
    return true
end



---Play everything (preferably on a separate thread).
---@return boolean completed Whether the playback succeded or not
function classPlayback:PlayThread()
    while not self.exit and self.playtime < self.length do
        if not self.decoded[self.playtime] then
            if self.jitDecode then
                self:Decode()
            else
                return false
            end
        end
        local decoded = self.decoded[self.playtime]
        local volume = self.volume
        while not self.playing do
            sleep(0)
        end
        local init = os.time(os.date("!*t"))
        for _, speaker in pairs(self.speakers) do
            speaker.playAudio(decoded, volume)
        end
        if self.jitDecode then
            self:Decode(self.playtime + 1)
        end
        os.pullEvent("speaker_audio_empty")
        print("Took " .. os.time(os.date("!*t")) - init)
        while not self.playing do
            sleep(0)
        end
        self.playtime = self.playtime + 1
    end
    return not self.exit
end



---Resume playback.
function classPlayback:Start()
    self.playing = true
end



---Stop playback.
function classPlayback:Stop()
    self.playing = false
    for _, speaker in pairs(self.speakers) do
        speaker.stop()
    end
end



---Toggle playback.
function classPlayback:Toggle()
    if self.playing then
        self:Stop()
    else
        self:Start()
    end
end



---Skip playback to index.
---@param time number Decoded index to skip to
function classPlayback:Skip(time)
    self.playtime = math.max(math.min(time, self.length), 1)
    if self.playing then
        self:Stop()
        self:Start()
    end
end



---Generate request URL.
---@param method string Method name, e.g. stream
---@param arguments table|nil Arguments to add to the URL
---@return string URL Base URL
local function makeRequestURL(method, arguments)
    local salt = ""
    for _ = 1, 8 do
        salt = salt .. string.format("%x", math.random(0, 15))
    end
    local url = Instance .. "/rest/" .. method .. "?u=" .. User .. "&t=" .. md5.sumhexa(Password .. salt) .. "&s=" .. salt .. "&c=SonicStreamer&v=1.16.1&f=json"
    if arguments ~= nil then
        for key, value in pairs(arguments) do
            url = url .. string.format("&%s=%s", key, tostring(value))
        end
    end
    return url
end



---Perform a basic, synchronous request
---@param url string Method name, e.g. stream
---@return table Response Parsed response
local function basicRequest(url)
    local response = http.get(url, {}, true)
    if not response then
        return {}
    end
    local decoded = textutils.unserializeJSON(response.readAll() or "")
    response:close()
    if not decoded then
        return {}
    end
    return decoded["subsonic-response"]
end



---Attempts to use the specified Subsonic server.
---@param instance string Instance URL, prefixed with protocol
---@param user string Username
---@param password string User password
---@returns boolean successful True if request succeeded
function Subsonic.login(instance, user, password)
    Instance = instance
    User = user
    Password = password
    return basicRequest(makeRequestURL("ping")).status == "ok"
end



---Get list of all albums
---@return table[] albums Format: {name = name, artist = artist, id = id}
function Subsonic.getAlbums()
    local response = basicRequest(makeRequestURL("getAlbumList", {type = "alphabeticalByName"}))
    local albums = {}
    for _, album in pairs(response.albumList.album) do
        table.insert(albums, {name = album.name, artist = album.artist, id = album.id})
    end
    return albums
end



---Get songs from album
---@param album table Album
---@return table[] songs Format: {name = name, id = id}
function Subsonic.getAlbumSongs(album)
    local response = basicRequest(makeRequestURL("getAlbum", {id = album.id}))
    local songs = {}
    for _, song in pairs(response.album.song) do
        table.insert(songs, {name = song.title, id = song.id})
    end
    return songs
end



---Get list of playlists.
---@return table[] playlists Format: {name = name, id = uuid, songCount = songCount}
function Subsonic.getPlaylists()
    local response = basicRequest(makeRequestURL("getPlaylists"))
    local playlists = {}
    for _, playlist in pairs(response.playlists.playlist) do
        table.insert(playlists, {name = playlist.name, id = playlist.id, songCount = playlist.songCount})
    end
    return playlists
end



---Get list of songs in a playlist.
---@param playlist table Playlist
---@return table[] songs Format: {name = name, id = id}
function Subsonic.getPlaylistSongs(playlist)
    local response = basicRequest(makeRequestURL("getPlaylist", {id = playlist.id}))
    if response.status == "failed" then
        return {}
    end
    local songs = {}
    for _, song in pairs(response.playlist.entry) do
        table.insert(songs, {name = song.title, id = song.id})
    end
    return songs
end



---Shuffle around songs in songs list
---@param songs table[] Songs
---@return table[] shuffled Shuffled songs
---@see Subsonic.getPlaylistSongs
function Subsonic.shufflePlaylist(songs)
    local shuffled = {}
    for i = 1, #songs do
        local newIndex
        repeat
            newIndex = math.random(1, #songs)
        until not shuffled[newIndex]
        shuffled[newIndex] = songs[i]
    end
    return shuffled
end



---Loads song and prepares for 
---@param song table Song UUID 
---@param speakers ccTweaked.peripherals.Speaker[]|ccTweaked.peripherals.Speaker Speaker(s) to play on
---@return Playback|nil playback Playback control
function Subsonic.playSong(song, speakers)
    http.request({ url = makeRequestURL("stream", {id = song.id, format = "dfpwm"}), binary = true, headers = {}, method = "GET" })
    local _, _, response = os.pullEvent("http_success", 120)
    if not response then
        return
    end
    local contents = response.readAll()
    response.close()
    if #contents == 0 then
        error("No audio data received! Make sure your transcoder settings are 100% correct (e.g. -f FFmpeg flag is set to dfpwm)", 0)
    end
    if #speakers == 0 then
        speakers = {speakers}
    end
    return classPlayback:New(contents, speakers)
end



return Subsonic