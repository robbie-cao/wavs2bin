# wavs2bin
Dump wav files raw pcm data into one binary with header

```
            0                4                8                12              16
0x00000000  +----------------+----------------+----------------+----------------+
            | magic          | total          | info           | misc           |
            |                |                |                |                |
            |                |                |                |                |
0x00000400  +----------------+----------------+----------------+----------------+
            | start sector   | size           | info           | misc           |
            | start sector   | size           | info           | misc           |
            |                |                |                |                |
            |                |                |                |                |
            |                |                |                |                |
0x00080000  +----------------+----------------+----------------+----------------+
            | reserved                                                          |
            |                                                                   |
            |                                                                   |
0x00100000  +----------------+----------------+----------------+----------------+
            | data                                                              |
            |                                                                   |
            |                                                                   |
0xNNNNNN00  +----------------+----------------+----------------+----------------+

```

## Reference

- http://perldoc.perl.org/functions/pack.html
- http://www.catonmat.net/download/perl.pack.unpack.printf.cheat.sheet.pdf
- https://github.com/robbie-cao/kb-audio/blob/master/ffmpeg.md#audio-format-conversions
- https://github.com/robbie-cao/piccolo#convert-audio-file
- man page of `echo`, `printf`, `cat`, `dd`, `awk`, `sed`, `hexdump`, `ffmpeg`
