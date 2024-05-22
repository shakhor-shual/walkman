#!/bin/bash
is_hashed() {
    local hashlist="/tmp/stage_hashlist"
    local hashed=1
    local md5
    touch "$hashlist"
    md5=$(echo -n "$*" | md5sum | awk '{print $1}')
    ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0

    for pm in "$@"; do
        if [[ $pm =~ "://" ]]; then    # is url
            if [[ $pm = *.git ]]; then # is git url
                hashed=0
            else # is non git url
                md5=$(echo "$pm" | md5sum | awk '{print $1}')
                ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
            fi
        else                      # is non url
            if [ -f "$pm" ]; then # is file
                md5=$(stat "$pm" -c %Y | sort -n | tail -n 1 | md5sum | awk '{print $1}')
                ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
            else                      # is non file
                if [ -d "$pm" ]; then # is dir
                    md5=$(stat "$pm/*" -c %Y | sort -n | tail -n 1 | md5sum | awk '{print $1}')
                    ! grep -q "$md5" <$hashlist && echo "$md5" >>$hashlist && hashed=0
                else # is non dir, non url, non file
                    hashed=$hashed
                fi
            fi
        fi
    done
    cat "$hashlist"
    return $hashed
}

is_hashed "$@"
