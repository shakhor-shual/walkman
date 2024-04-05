#!/bin/bash
###########################################################################
# Copyright The Vadym Yanik.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###########################################################################

ENV_PREFIX="CW4D_"
START_POINT=$PWD
DEBUG=0
TF_EC=0
RUN_LIST="init apply destroy validate describe gitops --list --host"

check_ansible_connection() {
    local group=${1:-"all"}
    local delay=${2:-"30"}
    echo "- hosts: $group" >"$ANSIBLE_CHECKER"
    echo "  gather_facts: no" >>"$ANSIBLE_CHECKER"
    echo "  tasks:" >>"$ANSIBLE_CHECKER"
    echo "  - name: Wait for hosts become reachable" >>"$ANSIBLE_CHECKER"
    echo "    ansible.builtin.wait_for_connection:" >>"$ANSIBLE_CHECKER"
    echo "      timeout: $delay" >>"$ANSIBLE_CHECKER"
    ansible-playbook -i "$ALBUM_ORIGIN" "$ANSIBLE_CHECKER"
}

################ EXTENTION HELPERS LIBRARY #############################
GET_from_state_by_type() {
    local val
    local stored_path=$PWD
    for stage_state_path in $(find "$ALBUM_HOME_DIR" -maxdepth 3 -name terraform.tfstate | sort); do
        val=""
        cd "$(dirname "$stage_state_path")" || exit
        if [ "$(terraform show -json | jq '.values.root_module.resources ')" != "null" ]; then
            val=$(terraform show -json | jq --arg resource "$1" --arg field "$2" '.values.root_module.resources[] | select(.type==$resource) | .values | .[$field]')
            if [ "$val" != "null" ] && [ "$val" != "" ]; then
                echo "$val"
                cd "$stored_path" || exit
                return 0
            fi
        fi
    done
    echo "NULL"
    cd "$stored_path" || exit
    return 1
}

SET_ansible_ready() {
    if [ -f "$INVENTORY_HOST" ] && [ -f "$INVENTORY_LIST_TAIL" ] && [ -f "$INVENTORY_LIST_HEAD" ]; then
        check_ansible_connection "$1" "$2" | grep ': \[' | tr -d '[' | tr -d ']' | tr '\n' ',' | tr -d ' ' | sed 's/.$//' | sed 's/^/"{/; s/$/}"/'
    else
        echo "{}"
    fi
}

SET_access_artefacts() {
    [ -z "$SINGLE_LABEL" ] && return
    local ips='[]'
    local user=$2
    local secret

    ips="$(extract_ip_from_state_file "$1")"
    echo " #!/bin/bash" >"$SINGLE_ECHO_FILE"
    echo "#~""$SINGLE_LABEL" >>"$SINGLE_ECHO_FILE"
    echo "# hosts:$ips" >>"$SINGLE_ECHO_FILE"

    if echo "$3" | grep -q "$META"; then
        secret=$PACK_HOME_FULL_PATH/$3
        echo "KEY_FILE=$secret" >>"$SINGLE_ECHO_FILE"
    else
        secret=$3
        echo "KEY_FILE=$secret" >>"$SINGLE_ECHO_FILE"
    fi

    print_hosts_for_list_request "$ips" "$user" "$secret": >>"$INVENTORY_LIST_HEAD"
    # ips=$(echo "$ips" | sed 's/,/ /;s/\[//;s/\]//')

    for ip in $(echo "$ips" | sed 's/,/ /;s/\[//;s/\]//'); do
        # echo "ssh-keygen -f ~/.ssh/known_hosts -R $ip " >>$SINGLE_ECHO_FILE
        #echo 'ssh  -o IdentitiesOnly=yes -i $KEY_FILE '$2'@'$ip >>$SINGLE_ECHO_FILE
        echo 'ssh  -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i $KEY_FILE '"$user"'@'"$ip" >>"$SINGLE_ECHO_FILE"
        print_hostvars_for_host_request "$ip" "$user" "$secret" >>"$INVENTORY_HOST"
        print_hostvars_for_list_request "$ip" "$user" "$secret" >>"$INVENTORY_LIST_TAIL"
    done

    cat "$SINGLE_ECHO_FILE" >"$IN_SINGLE_ECHO_FILE"
    chmod 777 "$SINGLE_ECHO_FILE"
    chmod 777 "$IN_SINGLE_ECHO_FILE"

    echo "$ips"
}

############### HELPERS EXECUTOR ##############
run_helper_by_name() {
    local helper_call_string
    local val
    local helper_name
    helper_call_string="$(echo "$2" | sed 's/<<<//g; s/|/ /g;')"
    helper_name="$(echo "$helper_call_string" | awk '{print $1}')"

    if helper_exists "$helper_name"; then
        val="$(eval "$helper_call_string $1")"
        if [ "$3" = "env" ]; then
            export CW4D_"$1"="$(eval echo "$val")" #$val
        else
            add_or_replace_var "$1" "$val"
        fi
    else
        finish_grace "err_helper" "$helper_name" "$ALBUM_ORIGIN"
    fi
}

helper_exists() { declare -F "$1" >/dev/null; }

############## LANG PROCESSING #################
increment_if_possible() {
    local val=$1
    echo "$val" | grep -vq '[0-9]' && printf "${1}" && return

    if [[ ${val} =~ ^(.*[^0-9])?([0-9]+)$ ]] && [[ ${#BASH_REMATCH[1]} -gt 0 ]]; then
        printf "%s%0${#BASH_REMATCH[2]}d" "${BASH_REMATCH[1]}" "$((10#${BASH_REMATCH[2]} + 1))" ||
            printf "%0${#BASH_REMATCH[2]}d" "$((10#${BASH_REMATCH[2]} + 1))" ||
            printf "${val}"
    else
        tail=$(echo $val | sed 's/.*[0-9]//g')
        head=$(echo $val | sed "s/$tail//")

        [[ ${head} =~ ^(.*[^0-9])?([0-9]+)$ ]] && [[ ${#BASH_REMATCH[1]} -gt 0 ]] &&
            printf "%s%0${#BASH_REMATCH[2]}d" "${BASH_REMATCH[1]}" "$((10#${BASH_REMATCH[2]} + 1))" ||
            printf "%0${#BASH_REMATCH[2]}d" "$((10#${BASH_REMATCH[2]} + 1))" ||
            printf "${head}"
        printf "${tail}"

    fi
}

detect_terraform_provider() {
    [ -f "$PACK_HOME_FULL_PATH/terraform.tfstate" ] && grep <"$PACK_HOME_FULL_PATH"/terraform.tfstate -q "https://www.googleapis.com/compute/" && echo "GCP" && exit
    echo "NaN"
}

extract_ip_from_state_file() {
    local provider
    local val='[]'
    provider=$(detect_terraform_provider)
    if [ "$provider" = "GCP" ]; then
        [ -f "$PACK_HOME_FULL_PATH/terraform.tfstate" ] && val="$(tr <"$PACK_HOME_FULL_PATH"/terraform.tfstate -d ' ' | grep "$1" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | tr '\n' ',' | sed 's/.$//')"
        echo "[$val]"
        return
    fi
    echo "[]"
}

to_bash_lang_translator() {
    local key_val
    local key
    local val
    key_val=$(echo "$1" | tr '$' '\0' | sed "s/\o0[A-Za-z]/$ENV_PREFIX&/g" | sed "s/$ENV_PREFIX\o0/\o0$ENV_PREFIX/g" | tr '\0' '$' | tr -d '"')

    if echo "$key_val" | grep -q '^<<<'; then
        key=$(echo "$key_val" | cut -d '|' -f 1 | sed 's/^<<<//')
        val=$key_val
    else
        key=$(echo "$key_val" | sed 's/=/\o0/' | cut -d $'\000' -f 1)
        val=$(echo "$key_val" | sed 's/=/\o0/' | cut -d $'\000' -f 2)
    fi
    echo "$val" | grep -q ':' || val=$(echo "$val" | sed 's/^{/[/; s/}$/]/;') # set correct type brakets for list type

    echo "$val" | grep -q '@@last$' && val='$'"$ENV_PREFIX$key"
    echo "$val" | grep -q '++last$' && val=$(increment_if_possible "$(eval echo '$'"$ENV_PREFIX$key")") && echo "=======$(eval echo '$'"$ENV_PREFIX$key")=============$val==========="
    # echo "$val" | grep -q '@@self' && val=$(echo '['$(extract_ip_from_state_file $(echo "$val" | cut -d '/' -f 2))']' | tr ' ' ',')
    if [ -n "$SINGLE_LABEL" ]; then
        echo "$val" | grep -q '@@meta' && val="$(echo "$val" | sed 's/@@meta/..\/.meta/')"
    else
        echo "$val" | grep -q '@@meta' && val="$ALBUM_HOME_DIR$(echo "$val" | sed 's/@@meta/\/.meta/')"
    fi

    if echo "$val" | grep -q '<<'; then # DO for HELPERS
        run_helper_by_name "$key" "$val" "$2"
    else # DO for VARIABLES
        val="$(eval echo "$val")"
        [ -z "$val" ] && return
        val=$(echo "$val" | sed 's/^/"/;  s/$/"/; ')
        if [ "$2" = "env" ]; then
            export CW4D_"$key"="$(eval echo "$val")"
            [ "$DEBUG" -ge 3 ] && echo "EVAL:==$key=$val=====>$key=$(eval echo "$val")=="
        else
            add_or_replace_var "$key" "$val"
        fi
    fi
}

############# VARs PROCESSING #################
add_or_replace_var() {
    local key=$1
    local val=$2
    if grep -Fq "$key=" "$TF_VARS"; then # REPLACE values for existed keys
        sed -i "/^$key=/c $key=$val" "$TF_VARS"
    else # ADD new key-value pairs
        echo "$key=$val" >>"$TF_VARS"
    fi
    # post tune structures in tfvars
    sed -i 's/="\[/=\["/g; s/\]"/"\]/g; s/="{/={"/g; s/}"/"}/g' "$TF_VARS"
    sed -i 's/\,/"\,"/g; s/\:/"\:"/g; s/""/"/g; s/"\:"\/\//\:\/\//g' "$TF_VARS"
}

export_vars_to_env() {
    if [ -n "$2" ]; then #fast - vars only
        for key_val in $(sed <"$1" 's/#.*$//;/^$/d' | grep '=' | grep -Ev '^~|<<<' | tr -d ' ' | grep -v '""' | sed 's/=~/=/;s/,~/,/;s/@@all/all/g'); do
            to_bash_lang_translator "$key_val" "env"
        done
    else #full-  vars & helpers
        for key_val in $(sed <"$1" 's/#.*$//;/^$/d' | grep -E '=|<<<' | grep -v '^~' | tr -d ' ' | grep -v '""' | sed 's/=~/=/;s/,~/,/;s/@@all/all/g'); do
            to_bash_lang_translator "$key_val" "env"
        done
    fi

    [ "$DEBUG" -ge 2 ] && echo "======== in ENV vars AFTER stage tune:=========" && export | grep $ENV_PREFIX | awk '{print $3}' | sed "s/$ENV_PREFIX//" && echo -e
}

draft_tfvars_from_packet_variables() {
    #  create ENV-based part of dynamic tfvars (lookup in packet variables.tf for each variable and assign its value from corresponding ENV var)
    grep <"$VARS_TF" '{' | grep variable | sed 's/"//g' | awk -v val="$ENV_PREFIX" '{print "echo " $2 "=$" val $2  }' | bash | sed 's/=/="/g' | sed 's/$/"/' | grep -v '""' >"$TF_VARS"
    [ "$DEBUG" -ge 1 ] && echo "================ DRAFTED tvfars: ===================" && cat "$TF_VARS" && echo -e
}

tune_tfvars_for_workflow() {
    # create template-based part of dynamic tfvar (just exclude all macro-defined variables and extract only inline-defined )
    [ "$DEBUG" -ge 1 ] && echo "======== in ENV vars BEFORE stage tune:=========" && export | grep $ENV_PREFIX | awk '{print $3}' | sed "s/$ENV_PREFIX//" && echo -e
    for key_val in $(grep <"$1" '^[[:lower:]]'); do
        to_bash_lang_translator "$key_val"
    done

    [ "$DEBUG" -ge 1 ] && echo "================ TUNED tvfars: ===================" && cat "$TF_VARS" && echo -e
}

################ DYNAMIC INVENTORY ####################
print_json_pair() {
    echo -n "\"$1\":\"$2\"$3"
}

print_hostvars_for_list_request() {
    echo -n "\"$1\": {"
    print_json_pair "ansible_user" "$2" ','
    #print_json_pair "host_key_checking" "False" ','
    print_json_pair "ansible_ssh_private_key_file" "$3" '}'
    echo -e
    echo ','
}

print_hosts_for_list_request() { #head
    local hosts
    hosts=${1//\"/} #$(echo "$1" | sed 's/"//g;')
    [ "$hosts" = "[]" ] && return
    hosts=$(echo "$hosts" | sed 's/\[/\["/;s/\]/"\]/; s/,/","/g')
    echo -n "\"$SINGLE_LABEL\":{"
    echo -n "\"hosts\":"
    echo -n "$hosts,"
    echo -n "\"vars\":{"
    print_json_pair "ansible_connection" "ssh" ','
    print_json_pair "become" "true" ','
    print_json_pair "become_user" "root" '}}'
    echo -e
    echo ','
}

print_hostvars_for_host_request() { #tail
    echo -n '{"_meta": {"hostvars": {'
    echo -n "\"$1\": {"
    print_json_pair "ansible_user" "$2" ','
    print_json_pair "ansible_ssh_private_key_file" "$3" '}}}}'
    echo -e
}

################# COMMONS ########################
it_contains() {
    if [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]; then
        return 0
    fi
    return 1
}

show_run_parameters() {
    if [ "$DEBUG" -ge 0 ]; then
        echo "== CW4D params:"
        echo '$'"0= $1"
        echo '$'"1= $2"
        echo '$'"2= $3"
        echo '$'"3= $4"
        echo '$'"4= $5"
        echo "======$RUN_MODE========="
    fi
}

set_debug_mode() {
    local debug
    local re='^[0-9]+$'
    debug="$(sed <"$ALBUM_ORIGIN" 's/#.*$//;/^$/d' | grep 'debug@@@' | tr -d ' ' | awk -F= '{print $2}')"
    [[ $debug =~ $re ]] && DEBUG=$debug
}

get_in_album_home() {
    local album=$1
    local album_home
    if [ -z "$album" ]; then
        album=$START_POINT/album.tpl.csh
        [ -f "$album" ] && cat"$album" >"$album".bak
        echo "#!/usr/local/bin/cw4d" >"$album"
        chmod 744 "$album"
    fi

    if [ -f "$album" ]; then
        album_home=$(dirname "$album")
        [ -d "$album_home" ] && cd "$album_home" || exit
        ALBUM_HOME_DIR=$PWD
        ALBUM_ORIGIN=$PWD/$(basename "$album")
        ALBUM_LOCK="$ALBUM_ORIGIN.lock"
        ALBUM_META_DIR="$ALBUM_HOME_DIR"/.meta
        ALBUM_TMP_DIR=$ALBUM_META_DIR/tmp
        [ -d "$ALBUM_TMP_DIR" ] || mkdir -p "$ALBUM_TMP_DIR"
        ALBUM_VARS_DRAFT="$ALBUM_TMP_DIR"/album_vars.draft
        INVENTORY_HOST=$ALBUM_TMP_DIR/inventoty_host.draft
        INVENTORY_LIST_HEAD=$ALBUM_TMP_DIR/inventoty_head.draft
        INVENTORY_LIST_TAIL=$ALBUM_TMP_DIR/inventoty_tail.draft
        ANSIBLE_CHECKER=$ALBUM_TMP_DIR/check_hosts.yml
        META="../.meta"
    fi
}

get_in_tf_packet_home() {
    PACK_HOME=$(find "$1" -maxdepth 2 -name main.tf)
    [ -z "$PACK_HOME" ] && return 1
    PACK_HOME=$(dirname "$PACK_HOME")
    TF_VARS="$PACK_HOME/terraform.tfvars"
    VARS_TF="$PACK_HOME/variables.tf"
    cd "$PACK_HOME" || exit
    PACK_HOME_FULL_PATH=$PWD
}

reset_album_tmp() {
    [ -d "$ALBUM_TMP_DIR" ] && rm -rf "$ALBUM_TMP_DIR"
    mkdir -p "$ALBUM_TMP_DIR"
}

finish_grace() {
    case "$1" in
    "err_tf")
        echo -e
        echo "################### TERRAFORM ERROR on Single-$2 ############################"
        echo "### IN: $3"
        echo "##################### ALBUM PLAYING CANCELED ###############################"
        echo -e && echo -e
        ;;

    "err_helper")
        echo -e
        echo "########################## PLAYLIST ERROR ##################################"
        echo "     HELPER with NAME: $2 STILL NOT EXIST in CW4D"
        echo "          CHECK your PLAYLIST file: $3"
        echo "  OR create/add your custom helper to implement THIS NEW request kind"
        echo "##################### ALBUM PLAYING CANCELED ###############################"
        echo -e && echo -e
        ;;
    *)
        echo -n "unknown"
        ;;
    esac
    unset ANSIBLE_HOST_KEY_CHECKING
    [ -f "$ALBUM_LOCK" ] && rm -f "$ALBUM_LOCK"
    cd "$START_POINT" && exit || exit
}

try_as_root() {
    if [ $EUID -eq 0 ]; then
        "${@}"
        return 0
    else
        if sudo -n true 2>/dev/null; then
            sudo "${@}"
            return 0
        else
            echo "!!!Don't possiible automatically run under sudo:"
            echo "${@}"
            return 1
        fi
    fi
}

init_home_local_bin() {
    local whoami
    local terraform_v=1.7.5

    if [ -z "$(which curl)" ] || [ -z "$(which pip3)" ] || [ -z "$(which unzip)" ] || [ -z "$(which shc)" ]; then
        try_as_root apt update
        try_as_root apt -y install curl python3-pip unzip shc
    fi

    [ -d ~/.local/bin ] || mkdir -p ~/.local/bin
    if [ $EUID -eq 0 ]; then
        echo "$PATH" | grep -q "/root/.local/bin" || export PATH=/root/.local/bin:$PATH
    else
        whoami=$(whoami)
        echo "$PATH" | grep -q "/home/$whoami/.local/bin" || export PATH=/home/$whoami/.local/bin:$PATH
    fi

    if [ -z "$(which terraform)" ]; then
        curl -o ~/.local/bin/terraform_linux_amd64.zip https://releases.hashicorp.com/terraform/${terraform_v}/terraform_${terraform_v}_linux_amd64.zip
        unzip -o ~/.local/bin/terraform_linux_amd64.zip -d ~/.local/bin
        rm -f ~/.local/bin/terraform_linux_amd64.zip
    fi

    if [ -z "$(which ansible)" ]; then
        python3 -m pip install --user ansible-core
    fi

    if [ -z "$(which helm)" ]; then
        try_as_root curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    if [ -z "$(which kubectl)" ]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv ./kubectl ~/.local/bin/kubectl
    fi
    export ANSIBLE_HOST_KEY_CHECKING=False
}

stage_kind_detect() {
    case $1 in
    *"variables.tf") echo "TF" ;;
    *".yaml") echo "ANS" ;;
    *"RUN") echo "RUN" ;;
    *"LOAD") echo "LOAD" ;;
    *) echo "UNKNOWN" ;;
    esac
}

root_template_print() {
    {
        echo "################# AUTO-GENERATED DEPLOYMENT-SCRIPT TEMPLATE #####################"
        echo "run@@@=init   #RUN-mode will used if another don't specefied (as script [PARAM])"
        echo "debug@@@=2    #VERBOSITY-level for script execution (0..3)"
        echo
        echo "ROOT:"
        echo "################## AUTO-GENERATED COMMON VARIABLES #####################"
        echo "########################################################################"
        echo "##### you can define own values, which will be automatically  ##########"
        echo "##### reused for ALL same named variables UNLESS THEY ARE    ###########"
        echo "########  EXPLICITLY ASSIGNED TO ANOTHER VALUES IN ANY WAY #############"
        echo "########################################################################"
        sed <"$2" 's/#.*$//;/^$/d;/^~/d;/@@last/d;s/@@/"value?"/ ' | tr -d ' ' | sort -u
        cat "$2"
    } >>"$1"
}

stage_template_print() {
    local label
    local kind

    kind=$(stage_kind_detect "$2")
    label=$(basename "$(dirname "$2")")
    [ "$kind" = "TF" ] && label=$(basename "$(dirname "$(dirname "$2")")")
    {
        echo
        echo "~${kind}_${label^^}:"
        echo "##################################################################"
        [ -n "$3" ] && echo "###^^^  This is an automatically generated stage label/name.   ###"
        [ -n "$3" ] && echo "###^^^  You can refer to this stage with it and/or change it.  ###"
        [ -n "$3" ] && echo "##################################################################"
        [ -n "$3" ] && echo "###  Here are the variables used in the stage, each of which   ###"
        [ -n "$3" ] && echo "###  is now automatically set to its default value (with the   ###"
        [ -n "$3" ] && echo "###  '@@' directive) The current (default) values are shown in ###"
        [ -n "$3" ] && echo "###  each end line comment, but you can set any of yor own     ###"
        [ -n "$3" ] && echo "##################################################################"
        [ "$kind" = "TF" ] && sed <"$2" 's/#.*$//;/^$/d' | grep -E 'variable|default' | tr -d ' ' | sed 's/^variable//' | sed ':a;N;$!ba;s/{\n/#/g' |
            sed 's/"//;s/"/=@@/;s/default=/@@=/' | sed 's/@@#"/=@@last\n/;s/"#"/=@@last\n/g;s/"#/=@@/;s/@@@@/@@#@@/;s/#@@/ #@@/' |
            column -t | sed 's/#@@/\t\t# @@/'
    } >>"$1"
}

print_help_info() {
    echo "   USAGE: cw4d [OPTION] some-deployment-script.csh"
    echo "OR* just: some-deployment-script.sch [OPTION]"
    echo -n
    echo "OPTION can be one of:"
    echo -n
    echo "   describe      make deployment-script template for existing"
    echo "                 structure of poject (for all current level sub-folders)"
    echo "   validate      validate terraform-defined infrastructure"
    echo "   init          init terraform-defined infrastructure"
    echo "   apply         apply terraform-defined infrastructure and setup it"
    echo "                 components (via ansible/helm/kubectl etc)"
    echo "   destroy       destroy deployed infrastructure"
    echo "   help          print this info"
    echo " Extra OPTIONS for ansible dynamic inventort support ONLY:"
    echo "   --list        don't used manually! "
    echo "   --host        don't used manually! "
    echo "==================================================="
    echo "*only if SHEBANG in some-deployment-script.csh set to:"
    echo "#!/usr/local/bin/cw4d"
}

perform_selfcompile() {
    echo "======================= CW4D self-compilation ================================"
    try_as_root /usr/bin/shc -vrf "$0" -o /usr/local/bin/cw4d
    try_as_root rm ./cw4d.sh.x.c
    echo "============================================================================="
    echo "========= CW4D now self-compiled to ELF-executable and ready to use ========="
    echo "========= try run: cw4d some_my_deploymet.sch                       ========="
    echo "========= OR just: /path-to-deployment-script/any_deploymet.sch     ========="
    echo "============================================================================="
    echo " WARNING: the second one will only work if your deployment-script "
    echo " has SHEBANG look like this: #!/usr/local/bin/cw4d"
    echo "============================================================================="
}

git_checkout() {
    [ -z "$2" ] && return 0
    git -C "$1" checkout "$2" | grep -q "up to date" && return 0
    return 1
}

git_clone_or_pull() {
    [ -z "$2" ] && return 0

    if [ -d "$1/.git" ]; then
        git -C "$1" pull | grep -q "up to date" && return 0
    else
        [ "$1" = "." ] && [ -f ".LOAD" ] && mv -f .LOAD /tmp/.LOAD
        [ "$1" = "." ] && [ -f "gitops.csh" ] && mv -f gitops.csh /tmp/gitops.csh
        [ "$1" = "." ] && rm -rf "${packet_dir:?}/"*
        [ "$1" = "." ] && rm -rf "${packet_dir:?}/."meta
        git clone "$2" "$1"
        [ "$1" = "." ] && [ -f "/tmp/.LOAD" ] && mv -f /tmp/.LOAD .LOAD
        [ "$1" = "." ] && [ -f "/tmp/gitops.csh" ] && mv -f /tmp/gitops.csh gitops.csh
    fi
    return 1
}

load_from_remote() {
    if echo "$1" | grep -q '.zip'; then
        curl -o stage_archive.zip "$1"
        if [ -n "$path" ]; then
            mkdir -p "$path"
            unzip -o stage_archive.zip -d "$path"
        else
            unzip -o stage_archive.zip
        fi
        rm -f stage_archive.zip
    else
        if [ -n "$path" ]; then
            curl -o "$1"
        else
            curl -o "$1"
        fi
    fi
    return 0
}

sync_remote_updates() {
    local get
    local git
    local branch
    local path
    local script
    local packet_dir
    local updated=1
    local apply_it=1

    while [ $updated -eq 1 ]; do
        updated=0
        for packet_path in $(find "$ALBUM_HOME_DIR" -maxdepth 2 -name ".LOAD" -o -name "gitops.csh" | grep -v '\.meta\|\.git' | sort); do
            cd "$ALBUM_HOME_DIR" || exit
            packet_dir=$(dirname "$packet_path")
            get=$(sed <"$packet_path" 's/#.*$//;/^$/d' | tr -d ' ' | grep '^get' | sed 's/^get=//;s/^get@@@=//' | head -n 1)
            git=$(sed <"$packet_path" 's/#.*$//;/^$/d' | tr -d ' ' | grep '^git' | sed 's/^git=//;s/^git@@@=//' | head -n 1)
            branch=$(sed <"$packet_path" 's/#.*$//;/^$/d' | tr -d ' ' | grep '^branch' | sed 's/^branch=//;s/^branch@@@=//' | head -n 1)
            path=$(sed <"$packet_path" 's/#.*$//;/^$/d' | tr -d ' ' | grep '^path' | sed 's/^path=//;s/^path@@@=//' | head -n 1)
            script=$(sed <"$packet_path" 's/#.*$//;/^$/d' | grep '^script' | sed 's/^script=//;s/^scripth@@@=//' | head -n 1)
            cd "$packet_dir" || exit
            if [ -n "$git" ]; then
                [ -z "$path" ] && path=$(echo "$git" | awk -F/ '{print $NF}' | sed 's/.git$//')
                ! git_clone_or_pull "$path" "$git" && apply_it=0 && updated=1 && break
                ! git_checkout "$path" "$branch" && apply_it=0 && updated=1 && break
            fi
            [ -n "$get" ] && load_from_remote "$get" && apply_it=0 && updated=1 && break
        done
        # echo "===$updated===="
    done

    cd "$ALBUM_HOME_DIR" || exit
    if [ -n "$script" ]; then
        get_in_album_home "$ALBUM_HOME_DIR"/${script}
    else
        get_in_album_home "$ALBUM_HOME"/album.csh
    fi
    return $apply_it
}

accept_inlines() {
    local stage_count=1
    for stage_path in $(
        find "$ALBUM_HOME_DIR" -maxdepth 1 -type d | sort | grep -v '\.meta\|\.git' | tail -n +2
    ); do

        if get_in_tf_packet_home "$stage_path"; then
            cat $stage_path/*.sch
        fi
        ((stage_count++))
    done
}

#====================================START of SCRIPT BODY ====================================
#start=$(date +%s.%N)
init_home_local_bin

if [ "$0" = "./cw4d.sh" ]; then
    perform_selfcompile
    exit
fi

if it_contains "$RUN_LIST" "$1"; then
    RUN_MODE="$1"
    get_in_album_home "$2"
else
    if it_contains "$RUN_LIST" "$2"; then
        RUN_MODE="$2"
        get_in_album_home "$1"
    else
        # show_run_parameters $0 $1 $2 $3
        echo "$2" | grep -q '/' && get_in_album_home "$2"
        echo "$1" | grep -q '/' && get_in_album_home "$1"
        RUN_MODE="$(sed <"$ALBUM_ORIGIN" 's/#.*$//;/^$/d' | grep 'run@@@' | tr -d ' ' | awk -F= '{print $2}')"
    fi
fi

! it_contains "$RUN_LIST" "$RUN_MODE" && echo "{ }" && exit

case $RUN_MODE in
"--host")
    if [ -n "$3" ]; then
        while IFS="" read -r host || [ -n "$host" ]; do
            echo "$host" | grep -q "$3" && echo "$host" && exit
        done <"$INVENTORY_HOST"
    fi
    echo "{ }" && exit
    ;;

"--list")
    echo -n "{"
    tr <"$INVENTORY_LIST_HEAD" -d ' ' | tr -d '\n'
    echo -n "\"_meta\": { \"hostvars\": {"
    tr <"$INVENTORY_LIST_TAIL" -d ' ' | tr -d '\n' | sed 's/.$//'
    echo -n "}}}"
    exit
    ;;

"help") print_help_info ;;

"destroy")
    touch "$ALBUM_LOCK"
    reset_album_tmp
    set_debug_mode
    for tf_packet_path in $(find "$ALBUM_HOME_DIR" -maxdepth 3 -name "variables.tf" | sort -r); do

        cd "$(dirname "$tf_packet_path")" || exit
        if [ -f "main.tf" ]; then
            echo "TERRAFORM ################ $tf_packet_path ############################"
            [ "$RUN_MODE" == "destroy" ] && terraform destroy -auto-approve
            echo "---------------------------------------------------------------------------------"
        fi
        cd "$START_POINT" || exit
    done
    [ -f "$ALBUM_LOCK" ] && rm -f "$ALBUM_LOCK"
    ;;

"describe")
    # reset_album_tmp
    stages_tmp=$(mktemp)
    head_tmp=$(mktemp)
    #set_debug_mode
    print_head_yes=yes
    for packet_path in $(find "$ALBUM_HOME_DIR" -maxdepth 3 -name "variables.tf" -o -name "*.yaml" -o -name ".RUN" | grep -v '\.meta\|\.git' | sort); do
        cd "$(dirname "$packet_path")" || exit
        stage_template_print "$stages_tmp" "$packet_path" $print_head_yes
        unset print_head_yes
        cd "$START_POINT" || exit
    done
    root_template_print "$head_tmp" "$stages_tmp"
    cat "$head_tmp" >>"$ALBUM_HOME_DIR"/album.tpl.csh

    rm -f "$stages_tmp" "$head_tmp"
    exit
    ;;

"apply" | "init" | "gitops")
    [ -f "$ALBUM_LOCK" ] && exit
    if ! sync_remote_updates; then
        if [ "$RUN_MODE" = "gitops" ]; then
            echo "gitops no changes"
            exit
        fi
    fi

    touch "$ALBUM_LOCK"
    reset_album_tmp
    set_debug_mode

    grep <"$ALBUM_ORIGIN" -v '@@@' | sed 's/#.*$//;/^$/d' | tr -d ' ' >"$ALBUM_VARS_DRAFT"
    export_vars_to_env "$ALBUM_VARS_DRAFT" "fast"
    sed <"$ALBUM_VARS_DRAFT" 's/^~/###~/' | csplit - -s '/^###~/' '{*}' -f "$ALBUM_TMP_DIR"/single -b "%02d_vars.draft"

    STAGE_COUNT=1
    for stage_path in $(
        find "$ALBUM_HOME_DIR" -maxdepth 1 -type d | sort | grep -v '\.meta\|\.git' | tail -n +2
    ); do
        SINGLE_INIT_FILE="$ALBUM_TMP_DIR/single"$(printf %02d $STAGE_COUNT)_vars.draft
        SINGLE_LABEL=$(head <"$SINGLE_INIT_FILE" -n 1 | sed 's/#//g;s/ //g;s/://g;s/~//g;')
        SINGLE_ECHO_FILE=$ALBUM_META_DIR/.ssh-$SINGLE_LABEL.sh
        IN_SINGLE_ECHO_FILE=$META/.$SINGLE_LABEL.sh

        echo -e
        echo "############################## Single-$STAGE_COUNT ################################"
        echo "### Single LABEL: $SINGLE_LABEL  "
        echo "### Single HOME: $stage_path"

        if get_in_tf_packet_home "$stage_path"; then #get in packet dir
            mkdir -p "$META"
            echo "#~""$SINGLE_LABEL" >"$IN_SINGLE_ECHO_FILE"
            draft_tfvars_from_packet_variables
            tune_tfvars_for_workflow "$SINGLE_INIT_FILE"
            export_vars_to_env "$TF_VARS" # export_vars_to_env "$TF_VARS"

            case $RUN_MODE in
            "init")
                echo "----------------------- Run TERRAFORM init ---------------------------------"
                terraform init --upgrade
                ;;
            "apply" | "gitops")
                touch "$ALBUM_LOCK"
                echo "------------------ Refresh TERRAFORM with init -----------------------------"
                terraform init --upgrade
                echo "---------------------- Run TERRAFORM apply ---------------------------------"
                terraform apply -auto-approve
                TF_EC=$?
                [ "$TF_EC" -eq 1 ] && finish_grace "err_tf" "$STAGE_COUNT" "$stage_path"
                export_vars_to_env "$SINGLE_INIT_FILE"
                ;;
            esac
            echo "----------------------------------------------------------------------------"
            cd "$ALBUM_HOME_DIR" || exit #return from packet to album level

        else
            echo "This not TF packet!!!"
            export_vars_to_env "$SINGLE_INIT_FILE"
        fi
        ((STAGE_COUNT++))
    done
    [ -f "$ALBUM_LOCK" ] && rm -f "$ALBUM_LOCK"
    ;;
*)
    #show_run_parameters $0 $1 $2 $3 $4
    ;;
esac

unset ANSIBLE_HOST_KEY_CHECKING
cd "$START_POINT" || exit
