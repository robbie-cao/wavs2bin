#!/bin/bash

#
# Memory Map (Draft - Furthe Define TBD)
#
#             0                4                8                12              16
# 0x00000000  +----------------+----------------+----------------+----------------+
#             | magic          | total          | info           | misc           |
#             |                |                |                |                |
#             |                |                |                |                |
# 0x00000400  +----------------+----------------+----------------+----------------+
#             | start sector   | size           | info           | misc           |
#             | start sector   | size           | info           | misc           |
#             |                |                |                |                |
#             |                |                |                |                |
#             |                |                |                |                |
# 0x00080000  +----------------+----------------+----------------+----------------+
#             | reserved                                                          |
#             |                                                                   |
#             |                                                                   |
# 0x00100000  +----------------+----------------+----------------+----------------+
#             | data                                                              |
#             |                                                                   |
#             |                                                                   |
# 0xNNNNNN00  +----------------+----------------+----------------+----------------+
#

function help {
    echo "Usage:"
    echo "$0 [path/to/wavs] [sample rate]"
    echo "    path/to/wavs (default: current folder)"
    echo "    sample rate = 16000 / 32000 / 44100 (default: 16000)"
}

path=$1
sample_rate=$2

if [[ "$1" == "help" || "$1" == "-h" ]]
then
    help
    exit 0
fi

if [[ "$path"x == ""x ]]
then
    path=`pwd`
fi

if [[ ! -d $path ]]
then
    echo -e "\033[0;33mDirectory not exist!\033[0m"
    help
    exit 1
fi

if [[ "$sample_rate"x == ""x ]]
then
    sample_rate=16000
fi

if [[ $sample_rate != 16000 && $sample_rate != 32000 && $sample_rate != 44100 ]]
then
    echo -e "\033[0;33mInvalid sample rate!\033[0m"
    help
    exit 1
fi

total=`ls -l $path/*.wav | wc -l`
if [[ $total -eq 0 ]]
then
    echo -e "\033[0;33mNot found wav files!\033[0m"
    help
    exit 1
fi

echo -e "\n"

rm -f *.bin *.pad

START_ADDR_HEADER=0x0
START_ADDR_INDEX=0x400
START_ADDR_RESV=0x80000
START_ADDR_FW=0x100000
START_ADDR_USRDATA=0x200000
START_ADDR_MD2SCR=0x300000
START_ADDR_DATA=0x400000

START_SECT_HEADER=$((START_ADDR_HEADER / 512))
START_SECT_INDEX=$((START_ADDR_INDEX / 512))
START_SECT_RESV=$((START_ADDR_RESV / 512))
START_SECT_FW=$((START_ADDR_FW / 512))
START_SECT_USRDATA=$((START_ADDR_USRDATA / 512))
START_SECT_MD2SCR=$((START_ADDR_MD2SCR / 512))
START_SECT_DATA=$((START_ADDR_DATA / 512))

echo -e "\033[0;31m-> Data Section\033[0m"

idx=0
file_num=0
file_list=`ls $path/*.wav`
start_sector=$START_SECT_DATA
start_addr=$START_ADDR_DATA

for file in $file_list
do
    file_num=`echo $file | awk -F "_" '{ print $2 }' | bc`
    if [[ $idx -lt $file_num ]]
    then
        for (( ; "$idx" < "$file_num"; idx = $idx + 1 ))
        do
            printf "%5d\t - empty\n" $idx
            perl -e "print pack(\"LLLL\", ($START_SECT_DATA, 0, 0, $START_ADDR_DATA))" >> index.bin
        done
    fi
    # wav -> raw
    # codec       : pcm_s16le
    # sample rate : 16000 / 32000 / 44100
    # channel     : 1 / 2
    ffmpeg -y -v warning -i $file -f s16le -acodec pcm_s16le -ar $sample_rate -ac 1 $file_num.raw

    file_size=`ls -l $file_num.raw | awk '{ print $5 }'`

    # padding
    sector_size=$((file_size / 512))
    tail_size=$((file_size % 512))
    padding_size=0
    if [[ $tail_size -ne 0 ]]
    then
        sector_size=$((sector_size + 1))
        padding_size=$((512 - tail_size))
    fi
    dd if=/dev/zero of=$file_num.pad bs=$padding_size count=1
    cat $file_num.raw $file_num.pad >> data.bin
    printf "%5d\t - size: %d, sector: %#08x, addr: %#08x, padding: %d\n" $file_num $file_size $start_sector $start_addr $padding_size


    perl -e "print pack(\"LLLL\", ($start_sector, $file_size, 0, $start_addr))" >> index.bin
    start_sector=$((start_sector + sector_size))
    start_addr=$((start_sector * 512))
    idx=$((file_num + 1))
done

echo -e "\033[0;31m-> Index Section\033[0m"

# index padding
index_size=`ls -l index.bin | awk '{ print $5 }'`
padding_size=$((START_ADDR_RESV - START_ADDR_INDEX - index_size))
dd if=/dev/zero of=index.pad bs=$padding_size count=1

echo -e "\033[0;31m-> Header Section\033[0m"

# header and padding
total=`ls -l $path/*.wav | wc -l`
perl -e "print pack(\"LLLL\", (0x12345678, $total, 0, 0))" >> header.bin
header_size=`ls -l header.bin | awk '{ print $5 }'`
padding_size=$((START_ADDR_INDEX - START_ADDR_HEADER - header_size))
dd if=/dev/zero of=header.pad bs=$padding_size count=1

echo -e "\033[0;31m-> Reserved Section\033[0m"

# reserved
dd if=/dev/zero of=reserved.bin bs=$((START_ADDR_FW - START_ADDR_RESV)) count=1

echo -e "\033[0;31m-> FW Section\033[0m"

# fw padding
fw_size=`ls -l $path/fw.bin | awk '{print $5 }'`
padding_size=$((START_ADDR_USRDATA - START_ADDR_FW - fw_size))
echo -e $padding_size
dd if=/dev/zero of=fw.pad bs=$padding_size count=1

echo -e "\033[0;31m-> User Data Section\033[0m"

# user data
dd if=/dev/zero of=usrdata.bin bs=$((START_ADDR_MD2SCR - START_ADDR_USRDATA)) count=1

echo -e "\033[0;31m-> Midi2Score Section\033[0m"

# midi2score data
file_list=`ls $path/*.mid`
for file in $file_list
do
    # midi -> score
    $path/midi2score $file

    file_size=`ls -l $file.ssc | awk '{ print $5 }'`

    # padding
    sector_size=$((file_size / 512))
    tail_size=$((file_size % 512))
    padding_size=0
    if [[ $tail_size -ne 0 ]]
    then
        sector_size=$((sector_size + 1))
        padding_size=$((512 - tail_size))
        dd if=/dev/zero of=$file.pad bs=$padding_size count=1
        cat $file.ssc $file.pad >> midi2score.bin
    else
        cat $file.ssc >> midi2score.bin
    fi
done

# midi2score padding
midi2score_size=`ls -l midi2score.bin | awk '{ print $5 }'`
padding_size=$((START_ADDR_DATA - START_ADDR_MD2SCR - midi2score_size))
dd if=/dev/zero of=midi2score.pad bs=$padding_size count=1

echo -e "\033[0;31m-> Merge \033[0m"

# header.bin + header.pad + index.bin + index.pad + reserved.bin + fw.bin + fw.pad  + userdata.bin + midi2score.bin + midi2score.pad + data.bin
cat header.bin header.pad index.bin index.pad reserved.bin $path/fw.bin fw.pad usrdata.bin midi2score.bin midi2score.pad data.bin > output.fls

#remove tmp intermidates
rm -f *.bin *.pad *.raw *.ssc

# result
mv output.fls flash.bin

echo "Total: $total"
echo -e "\n"
echo -e "\033[0;31mDone!\033[0m"
