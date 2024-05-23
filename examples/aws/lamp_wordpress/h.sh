#!/bin/bash
is_hashed() {
    local hashlist="/tmp/stage_hashlist"
    local hashed=1
    local md5
    local cnt=$#
    touch "$hashlist"
    md5=$(echo -n "$*" | md5sum | awk '{print $1}')
    ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
    cnt=2
    local i=0
    for pm in "$@"; do
        echo "11111111"
        [ $i -ge $cnt ] && break
        if [[ $pm =~ "://" ]]; then    # is url
            if [[ $pm = *.git ]]; then # is git url
                hashed=0
            else # is non git url
                md5=$(echo "$pm" | md5sum | awk '{print $1}')
                ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
            fi
        else                      # is non url
            if [ -f "$pm" ]; then # is file
                echo '22222222222222'
                md5=$(stat "$pm" -c %Y | sort -n | tail -n 1 | md5sum | awk '{print $1}')
                ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
            else                      # is non file
                if [ -d "$pm" ]; then # is dir
                    md5=$(stat "$pm/*" -c %Y | sort -n | tail -n 1 | md5sum | awk '{print $1}')
                    ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
                else # is non dir, non url, non file
                    echo "88888888"
                    hashed=$hashed
                fi
            fi
        fi
        ((i++))
    done
    cat "$hashlist"
    rm "$hashlist"
    echo "=====$cnt====="
    return $hashed
}

is_hashed "$@"
