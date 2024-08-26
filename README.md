# SonicStreamer
ComputerCraft music player that streams your favourite music from your own Subsonic server. Fork of [Blahaj Subsonic Player](https://github.com/aspen-reeves/bsp)

## Instalation
Currently in a state of huge rewrites/implementations meaning this is currently unusable.

## Roadmap
- Extend Subsonic API implementation
- GUI (Probably Basalt)

## Server Configuration
- I personally use navidrome as my Subsonic server, but this should work with any Subsonic API compatible server
- To get dfpwm encoding support, you need to enable the `ND_ENABLETRANSCODINGCONFIG` setting in Navidrome, and add a new encoder with the following settings:

  - `Name`: dfpwm (this can actually be whatever you want)
  - `Target Format`: dfpwm
  - `Default Bit Rate`: 48
  - `Command`:

```sh
 ffmpeg -i %s -c:a dfpwm -ar 48k -ac 1 -f dfpwm -
```

> Warning: This setting allows for any arbitrary command to be run on the server, so be careful with what you put in here and who has access to it

## Credit and License
- In some parts based on [Blahaj Subsonic Player](https://github.com/aspen-reeves), licensed under [FAFO-2-CLAUSE version 2](https://github.com/aspen-reeves/FAFO-PL)
- This repository includes md5.lua, License MIT, Copyright (c) 2013 Enrique García Cota + Adam Baldwin + hanzao + Equi 4 Software
- The rest of this code is licensed under the FAFO-2-CLAUSE version 2, [a permissive public license](https://github.com/aspen-reeves/FAFO-PL)
