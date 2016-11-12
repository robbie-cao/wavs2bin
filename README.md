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
