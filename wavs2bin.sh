#!/bin/bash

function help {
    echo "Usage:"
    echo "$0 [path/to/wavs]"
}

path=$1

if [[ "$path"x = ""x ]]
then
    path=`pwd`
fi

if [[ "$path"x = "?"x ]]
then
    help
fi

if [[ ! -d $path ]]
then
    echo "Directory not exist!"
    help
    exit 1
fi

help

echo -e "\n"

rm -f *.bin *.pad

START_ADDR_HEADER=0x0
START_ADDR_INDEX=0x400
START_ADDR_RESV=0x80000
START_ADDR_DATA=0x100000

START_SECT_HEADER=$((START_ADDR_HEADER / 512))
START_SECT_INDEX=$((START_ADDR_INDEX / 512))
START_SECT_RESV=$((START_ADDR_RESV / 512))
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
    ffmpeg -y -v warning -i $file -f s16le -acodec pcm_s16le -ar 16000 -ac 1 $file_num.raw

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
    start_sector=$((START_SECT_DATA + sector_size))
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
dd if=/dev/zero of=reserved.bin bs=$((START_ADDR_DATA - START_ADDR_RESV)) count=1

echo -e "\033[0;31m-> Merge \033[0m"

# header + index + reserved + data -> flash.bin
cat header.bin header.pad index.bin index.pad reserved.bin data.bin > output.fls

# remove tmp intermidates
rm -f *.bin *.pad *.raw
# result
mv output.fls flash.bin

echo "Total: $total"
echo -e "\n"

echo -e "\033[0;31mDone!\033[0m"

