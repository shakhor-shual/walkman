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
#########################################################################
TERRAFORM_v=1.7.5
JQ_v=1.7.1
K9S_v="0.32.4"
ENV_PREFIX="CW4D_"
START_POINT=$PWD
DEBUG=0
TF_EC=0
RUN_LIST="init apply destroy validate describe gitops plan --list --host"

check_ansible_connection() {
    local group=${1:-"all"}
    local delay=${2:-"30"}
    echo "- hosts: $group" >"$ANSIBLE_CHECKER"
    echo "  gather_facts: no" >>"$ANSIBLE_CHECKER"
    echo "  tasks:" >>"$ANSIBLE_CHECKER"
    echo "  - name: Wait for hosts become reachable" >>"$ANSIBLE_CHECKER"
    echo "    ansible.builtin.wait_for_connection:" >>"$ANSIBLE_CHECKER"
    echo "      timeout: $delay" >>"$ANSIBLE_CHECKER"
    ansible-playbook -i "$ALBUM_SELF" "$ANSIBLE_CHECKER"
}

################ EXTENTION HELPERS LIBRARY #############################
GET_from_state_by_type() {
    local val
    local stored_path=$PWD
    for stage_state_path in $(find "$DIR_ALBUM_HOME" -maxdepth 3 -name variables.tf | sort); do
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

    if echo "$3" | grep -q "$DIR_META"; then
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

    #  cat "$SINGLE_ECHO_FILE" >"$IN_SINGLE_ECHO_FILE"
    chmod 777 "$SINGLE_ECHO_FILE"
    #  chmod 777 "$IN_SINGLE_ECHO_FILE"

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
        finish_grace "err_helper" "$helper_name" "$ALBUM_SELF"
    fi
}

helper_exists() { declare -F "$1" >/dev/null; }

############## LANG PROCESSING #################
increment_if_possible() {
    local val=$1
    local head
    local tail
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
    [ -f "$1" ] && grep <"$1" -q "https://www.googleapis.com/compute/" && echo "GCP" && exit
    [ -f "$1" ] && grep <"$1" -q "registry.terraform.io/hashicorp/aws" && echo "AWS" && exit
    [ -f "$1" ] && grep <"$1" -q "registry.terraform.io/hashicorp/azurerm" && echo "AZURE" && exit
    echo "NaN"
}

extract_ip_from_state_file() {
    local provider
    local state_file
    local val='[]'
    local ip_name=$1
    state_file=$(find "$PACK_HOME_FULL_PATH" -maxdepth 3 -type f -name terraform.tfstate | grep "/$WS_NAME/")
    provider=$(detect_terraform_provider "$state_file")
    if [ "$1" = "IP" ] || [ "$1" = "IP-public" ] || [ "$1" = "IP_public" ]; then
        [ "$provider" = "GCP" ] && ip_name="nat_ip"
        [ "$provider" = "AWS" ] && ip_name="public_ip"
        [ "$provider" = "AZURE" ] && ip_name="ip_address"
    fi
    if [ "$1" = "IP-private" ] || [ "$1" = "IP_private" ]; then
        [ "$provider" = "GCP" ] && ip_name="private_ip"
        [ "$provider" = "AWS" ] && ip_name="private_ip"
        [ "$provider" = "AZURE" ] && ip_name="private_ip_address"
    fi
    if [ "$provider" = "GCP" ] || [ "$provider" = "AWS" ] || [ "$provider" = "AZURE" ]; then
        [ -f "$state_file" ] && val="$(tr <"$state_file" -d ' ' | tr -d '"' | grep "^$ip_name" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -u | tr '\n' ',' | sed 's/.$//')"
        echo "[$val]"
        return
    fi
    echo "[]"
}

var_not_exported() {
    export | grep -q "$ENV_PREFIX$1" && return 1
    return 0
}

bashcl_translator() {
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

    if echo "$val" | grep -q '@@last$'; then
        var_not_exported "$key" && return
        #val='$'"$ENV_PREFIX$key"
        val=$(echo "$val" | tr '$' '\0' | sed "s/@@last/\o0$ENV_PREFIX$key/g" | tr '\0' '$')
    fi
    if echo "$val" | grep -q '++last$'; then
        var_not_exported "$key" && return
        val=$(increment_if_possible "$(eval echo '$'"$ENV_PREFIX$key")")
        # echo "=======$(eval echo '$'"$ENV_PREFIX$key")=============$val==========="
    fi
    # echo "$val" | grep -q '@@self' && val=$(echo '['$(extract_ip_from_state_file $(echo "$val" | cut -d '/' -f 2))']' | tr ' ' ',')
    if [ -n "$SINGLE_LABEL" ]; then
        echo "$val" | grep -q '@@meta' && val="$(echo "$val" | sed 's/@@meta/..\/.meta/')"
    else
        echo "$val" | grep -q '@@meta' && val="$DIR_ALBUM_HOME$(echo "$val" | sed 's/@@meta/\/.meta/')"
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
            bashcl_translator "$key_val" "env"
        done
    else #full-  vars & helpers
        for key_val in $(sed <"$1" 's/#.*$//;/^$/d' | grep -E '=|<<<' | grep -v '^~' | tr -d ' ' | grep -v '""' | sed 's/=~/=/;s/,~/,/;s/@@all/all/g'); do
            bashcl_translator "$key_val" "env"
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
        bashcl_translator "$key_val"
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
    debug="$(sed <"$ALBUM_SELF" 's/#.*$//;/^$/d' | grep 'debug@@@' | tr -d ' ' | sed 's/^debug@@@=//; s/^debug@@@//' | tail -n 1)"
    [[ $debug =~ $re ]] && DEBUG=$debug
}

init_album_home() {
    local album=$1
    local album_home
    local album_name

    if [ -z "$album" ]; then
        album=$START_POINT/album.tpl.csh
        [ -f "$album" ] && cat"$album" >"$album".bak
        echo "#!/usr/local/bin/cw4d" >"$album"
        chmod 744 "$album"
    fi
    if [ -f "$album" ]; then
        #   ALBUM=$album
        album_home=$(dirname "$album")
        album_name=$(basename "$album")
        [ -d "$album_home" ] && cd "$album_home" || exit
        WS_NAME=$(echo "$album_name" | tr '[:upper:]' '[:lower:]' | sed 's/\.csh//;s/_/-/g;s/\./-/g;s/ /-/g;s/^default$/default-d/')
        DIR_ALBUM_HOME=$PWD
        ALBUM_SELF="$DIR_ALBUM_HOME/$album_name"
        DIR_ALBUM_META="$DIR_ALBUM_HOME/.meta"
        DIR_WS_TMP="$DIR_ALBUM_META/$WS_NAME/tmp"
        mkdir -p "$DIR_WS_TMP"
        FLAG_LOCK="$DIR_ALBUM_HOME/.album.lock"
        FLAG_ERR="$DIR_ALBUM_HOME/.album.err"
        FLAG_OK="$DIR_ALBUM_HOME/.album.$WS_NAME.ok"
        ALBUM_VARS_DRAFT="$DIR_WS_TMP/$WS_NAME.vars.draft"
        ALBUM_EXEC_DRAFT="$DIR_WS_TMP/$WS_NAME.exec.draft"
        cat "$ALBUM_SELF" >"$ALBUM_EXEC_DRAFT"
        INVENTORY_HOST="$DIR_WS_TMP/$WS_NAME.inventoty_host.draft"
        INVENTORY_LIST_HEAD="$DIR_WS_TMP/$WS_NAME.inventoty_head.draft"
        INVENTORY_LIST_TAIL="$DIR_WS_TMP/$WS_NAME.inventoty_tail.draft"
        ANSIBLE_CHECKER=$DIR_WS_TMP/check_hosts.yml
        DIR_META="../.meta"
    fi
}

test_exec_packet_home() {
    local pack_type="SH"
    PACK_HOME=$(find "$1" -maxdepth 2 -name "*.sh" -exec dirname {} \; | sort -u | head -n 1)
    if [ -z "$PACK_HOME" ]; then
        PACK_HOME=$(find "$1" -maxdepth 2 -name "*.yaml" -exec dirname {} \; | sort -u | head -n 1)
        [ -z "$PACK_HOME" ] && PACK_HOME=$(find "$1" -maxdepth 2 -name "*.yml" -exec dirname {} \; | sort -u | head -n 1)
        [ -z "$PACK_HOME" ] && echo "NaN" && return
        pack_type="YAML"
    fi
    cd "$PACK_HOME" || exit
    PACK_HOME_FULL_PATH=$PWD
    echo $pack_type
}

get_in_tf_packet_home() {
    PACK_HOME=$(find "$1" -maxdepth 2 -name "*.tf" -exec dirname {} \; | sort -u | head -n 1)
    [ -z "$PACK_HOME" ] && return 1
    TF_VARS="$PACK_HOME/terraform.tfvars"
    VARS_TF="$PACK_HOME/variables.tf"
    cd "$PACK_HOME" || exit
    PACK_HOME_FULL_PATH=$PWD
}

reset_album_tmp() {
    [ -d "$DIR_WS_TMP" ] && rm -rf "$DIR_WS_TMP"
    mkdir -p "$DIR_WS_TMP"
}

finish_grace() {
    case "$1" in
    "err_tf")
        echo -e
        echo "################### TERRAFORM ERROR on Stage-$2 ############################"
        echo "### IN: $3"
        echo "##################### ALBUM DEPLOYMENT CANCELED #############################"
        echo -e && echo -e

        if [ "$RUN_MODE" = "gitops" ]; then
            echo "####################### AUTO ROLLBACK WRECKAGE #############################"
            destroy_deployment
            echo "############## CANCELED DEPLOYMENT WRECKAGE CLEANED UP #####################"
        fi
        touch "$FLAG_ERR"
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
    [ -f "$FLAG_LOCK" ] && rm -f "$FLAG_LOCK"
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

fix_user_home() {
    [ -z "$1" ] && return
    [ "$1" = "root" ] && return
    [ -d "/home/$1" ] && try_as_root chown -R "$1":"$1" "/home/$1"
}

not_installed() {
    for item in "$@"; do
        [ -z "$(which "$item")" ] && return 0
    done
    return 1
}

system_pakages_install() {
    if not_installed wget curl pip3 unzip shc rsync csplit; then
        if [ -n "$(which apt-get)" ]; then
            try_as_root apt update
            try_as_root apt -y install wget curl unzip shc rsync python3-pip coreutils tig
            return
        fi
        if [ -n "$(which yum)" ]; then
            try_as_root yum install epel-release
            try_as_root yum install wget curl unzip shc rsync python-pip coreutils
            return
        fi
        if [ -n "$(which dnf)" ]; then
            try_as_root dnf install epel-release
            try_as_root dnf install wget curl unzip shc rsync python-pip coreutils
            return
        fi
    fi
}

init_home_local_bin() {
    local user
    local user_home_local
    local user_home_bin
    local arch=amd64

    if [ -n "$1" ] && getent passwd "$1" >/dev/null 2>&1; then
        user=$1
    else
        user=$(whoami)
    fi

    system_pakages_install

    user_home_local=/home/$user/.local
    [ "$user" = "root" ] && user_home_local=/root/.local
    user_home_bin=$user_home_local/bin

    if [ ! -d "$user_home_bin" ]; then
        try_as_root mkdir -p "$user_home_bin"
        fix_user_home "$user"
    fi
    echo "$PATH" | grep -q "$user_home_bin" || export PATH=$user_home_bin:$PATH

    if not_installed docker podman; then
        if grep </etc/os-release -q "Amazon Linux"; then
            if grep </etc/os-release -q "Amazon Linux 2023"; then
                try_as_root yum install -y docker
            else
                try_as_root amazon-linux-extras install docker
            fi
            try_as_root service docker start
        else
            curl -fsSL https://get.docker.com -o get-docker.sh
            try_as_root sh ./get-docker.sh
            try_as_root systemctl enable /usr/lib/systemd/system/docker.service
        fi
        try_as_root usermod -aG docker "$user"
    fi

    if not_installed jq; then
        try_as_root curl -Lo "$user_home_bin/jq" https://github.com/jqlang/jq/releases/download/jq-${JQ_v}/jq-linux-${arch}
        try_as_root chmod +x "$user_home_bin/jq"
    fi

    if not_installed terraform; then
        try_as_root curl -Lo "$user_home_bin/terraform_linux_${arch}.zip" https://releases.hashicorp.com/terraform/${TERRAFORM_v}/terraform_${TERRAFORM_v}_linux_${arch}.zip
        try_as_root unzip -o "$user_home_bin/terraform_linux_${arch}.zip" -d "$user_home_bin"
        try_as_root rm -f "$user_home_bin/terraform_linux_${arch}.zip"
    fi

    if not_installed ansible; then
        if [ "$user" = "$(whoami)" ]; then
            python3 -m pip install --user ansible-core
        else
            sudo -H -u "$user" python3 -m pip install --user ansible-core
            fix_user_home "$user"
        fi
    fi

    if not_installed helm; then
        try_as_root curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    if not_installed kubectl; then
        try_as_root curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${arch}/kubectl"
        try_as_root chmod +x kubectl
        try_as_root mv ./kubectl "$user_home_bin"/kubectl
        fix_user_home "$user"
    fi

    if not_installed kubectl; then
        try_as_root curl -s -L https://github.com/derailed/k9s/releases/download/v${K9S_v}/k9s_Linux_${arch}.tar.gz | try_as_root tar xvz -C "$user_home_bin"
        try_as_root chmod +x "$user_home_bin/k9s"
        fix_user_home "$user"
    fi
}

stage_kind_detect() {
    case $1 in
    *".tf")
        echo "TF"
        return
        ;;
    *".yaml")
        [ "$(grep <"$1" "kind\|spec\|apiVersion" | tr -d ' ' | cut -d ':' -f 1 | sort -u | wc -l)" -ge 3 ] && echo "K8S" && return
        echo "ANS"
        return
        ;;
    *".yml")
        [ "$(grep <"$1" "kind\|spec\|apiVersion" | tr -d ' ' | cut -d ':' -f 1 | sort -u | wc -l)" -ge 3 ] && echo "K8S" && return
        echo "ANS"
        return
        ;;
    *".sh")
        echo "SH"
        return
        ;;
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
    local self=$0
    local self_path
    [ -n "$1" ] && self=$1
    self_path=$(dirname "$self")
    echo "======================= CW4D self-compilation ================================"
    try_as_root /usr/bin/shc -vrf "$self" -o /usr/local/bin/cw4d
    try_as_root rm "$self_path/cw4d.sh.x.c"
    [ "$self_path" != "/usr/local/bin" ] && try_as_root cp -f "$self_path/cw4d.sh" "/usr/local/bin/cw4d.sh"
    [ -s "$self_path/cw4d.sh" ] && try_as_root chmod 777 "$self_path/cw4d.sh"
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
    local tmp
    if [ -d "$1/.git" ]; then
        git -C "$1" pull | grep -q "up to date" && return 0
    else
        if [ "$1" = "." ]; then
            tmp=$(mktemp -d)
            mv ./*.csh "$tmp" 2>/dev/null
            rm -rf "${packet_dir:?}/"*
            rm -rf "${packet_dir:?}/."meta
        fi
        git clone "$2" "$1"
        if [ "$1" = "." ]; then
            mv -n "$tmp/"*.csh . 2>/dev/null
            rm -rf "$tmp"
        fi
    fi
    return 1
}

update_from_git() {
    local branch
    local path
    local url
    local packet_dir
    local updated=1
    local apply_it=1

    while [ $updated -eq 1 ]; do
        updated=0
        for packet_path in $(find "$DIR_ALBUM_HOME" -maxdepth 2 -name "*.csh" | grep -v '\.meta\|\.git' | sort); do
            cd "$DIR_ALBUM_HOME" || exit
            packet_dir=$(dirname "$packet_path")
            for git in $(sed <"$packet_path" 's/#.*$//;/^$/d' | tr -d ' ' | grep '^git' | sed 's/^git=//;s/^git@@@=//; s/^git@@@//;'); do
                url=$(echo "$git" | cut -d'>' -f 1 | cut -d'^' -f 1)
                [[ $git =~ "^" ]] && branch=$(echo "$git" | cut -d'>' -f 1 | cut -d'^' -f 2)
                path=$(echo "$git" | cut -d'>' -f 2)
                cd "$packet_dir" || exit
                if [ -n "$url" ]; then
                    [ -z "$path" ] && path=$(echo "$url" | awk -F/ '{print $NF}' | sed 's/.git$//')
                    ! git_clone_or_pull "$path" "$url" && apply_it=0 && updated=1 && break
                    ! git_checkout "$path" "$branch" && apply_it=0 && updated=1 && break
                    unset path
                    unset url
                    unset branch
                fi
            done
            [ $updated -eq 1 ] && break
        done
    done
    cd "$DIR_ALBUM_HOME" || exit
    return $apply_it
}

destroy_deployment() {
    [ -f "$FLAG_OK" ] && rm -f "$FLAG_OK"
    touch "$FLAG_LOCK"
    reset_album_tmp
    set_debug_mode
    for tf_packet_path in $(find "$DIR_ALBUM_HOME" -maxdepth 3 -name "variables.tf" | sort -r); do

        cd "$(dirname "$tf_packet_path")" || exit
        terraform workspace select -or-create "$WS_NAME"
        if [ -f "variables.tf" ]; then
            echo "TERRAFORM ################ $tf_packet_path ############################"
            terraform destroy -auto-approve
            echo "---------------------------------------------------------------------------------"
        fi
        cd "$START_POINT" || exit
    done
    [ -f "$FLAG_LOCK" ] && rm -f "$FLAG_LOCK"
}

#====================================START of SCRIPT BODY ====================================
#start=$(date +%s.%N)

if [[ $0 =~ bash$ ]]; then
    init_home_local_bin "$1"
    [ -s "/usr/local/bin/cw4d.sh" ] && perform_selfcompile "/usr/local/bin/cw4d.sh"
    exit
fi

if [[ $0 =~ /cw4d\.sh$ ]]; then
    if [ -z "$1" ] || getent passwd "$1" >/dev/null 2>&1; then
        init_home_local_bin "$1"
        perform_selfcompile "$0"
        exit
    else
        ssh "$@" "sudo tee -a /usr/local/bin/cw4d.sh;sudo chmod 777 /usr/local/bin/cw4d.sh;/usr/local/bin/cw4d.sh " <"$0"
        exit
    fi
fi
#show_run_parameters $0 $1 $2 $3 $4
#exit
if it_contains "$RUN_LIST" "$1"; then
    RUN_MODE="$1"
    SELF="$2"
    init_album_home "$2"
else
    if it_contains "$RUN_LIST" "$2"; then
        RUN_MODE="$2"
        init_album_home "$1"
        SELF="$1"
    else
        # show_run_parameters $0 $1 $2 $3
        echo "$2" | grep -q '/' && SELF="$2" && init_album_home "$2"
        echo "$1" | grep -q '/' && SELF="$1" && init_album_home "$1"
        RUN_MODE="$(sed <"$ALBUM_SELF" 's/#.*$//;/^$/d' | grep 'run@@@' | tr -d ' ' | sed 's/^run@@@=//; s/^run@@@//' | tail -n 1)"

    fi
fi
[ -n "$3" ] && it_contains "$RUN_LIST" "$3" && RUN_MODE=$3
! it_contains "$RUN_LIST" "$RUN_MODE" && echo "{ }" && exit
export ANSIBLE_HOST_KEY_CHECKING=False
#echo "************$RUN_MODE *******************"
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
    for album_script in ./*.csh; do
        ! grep <"$SELF" -q "^~" || [ "$album_script" = "$SELF" ] || continue
        grep <"$album_script" -q "^~" || continue
        init_album_home "$album_script"
        destroy_deployment
    done
    ;;

"describe")
    stages_tmp=$(mktemp)
    head_tmp=$(mktemp)
    print_head_yes=yes
    for packet_path in $(find "$DIR_ALBUM_HOME" -maxdepth 3 -name "variables.tf" -o -name "*.yaml" -o -name ".RUN" | grep -v '\.meta\|\.git' | sort); do
        cd "$(dirname "$packet_path")" || exit
        stage_template_print "$stages_tmp" "$packet_path" $print_head_yes
        unset print_head_yes
        cd "$START_POINT" || exit
    done
    root_template_print "$head_tmp" "$stages_tmp"
    cat "$head_tmp" >>"$DIR_ALBUM_HOME"/album.tpl.csh
    rm -f "$stages_tmp" "$head_tmp"
    exit
    ;;

"apply" | "init" | "plan" | "gitops")
    [ -f "$FLAG_LOCK" ] && exit
    if ! update_from_git; then
        if [ "$RUN_MODE" = "gitops" ] && [ ! -f "$FLAG_ERR" ]; then
            echo "gitops: no changes, no crashes"
            exit
        fi
    fi

    for album_script in ./*.csh; do
        ! grep <"$SELF" -q "^~" || [ "$album_script" = "$SELF" ] || continue
        grep <"$album_script" -q "^~" || continue
        init_album_home "$album_script"
        [ -f "$FLAG_OK" ] && rm -f "$FLAG_OK"
        touch "$FLAG_LOCK"
        reset_album_tmp
        set_debug_mode

        grep <"$ALBUM_SELF" -v '@@@' | sed 's/#.*$//;/^$/d' | tr -d ' ' | sed "s/@@this/$WS_NAME/g;/=@@$/d" >"$ALBUM_VARS_DRAFT"
        export_vars_to_env "$ALBUM_VARS_DRAFT" "fast"
        sed <"$ALBUM_VARS_DRAFT" 's/^~/###~/' | csplit - -s '/^###~/' '{*}' -f "$DIR_WS_TMP/$WS_NAME" -b "%02d_vars.draft"

        STAGE_COUNT=1
        for stage_path in $(
            find "$DIR_ALBUM_HOME" -maxdepth 1 -type d | sort | grep -v '\.meta\|\.git' | tail -n +2
        ); do
            SINGLE_INIT_FILE="$DIR_WS_TMP/$WS_NAME"$(printf %02d $STAGE_COUNT)_vars.draft
            SINGLE_LABEL=$(head <"$SINGLE_INIT_FILE" -n 1 | sed 's/#//g;s/ //g;s/://g;s/~//g;')
            SINGLE_ECHO_FILE=$DIR_ALBUM_META/ssh-to-$WS_NAME-$SINGLE_LABEL.sh
            #  IN_SINGLE_ECHO_FILE=$DIR_META/.$SINGLE_LABEL.sh

            echo
            echo "############################## Stage-$STAGE_COUNT ################################"
            echo "### Stage LABEL: $SINGLE_LABEL  "
            echo "### Stage HOME: $stage_path"
            echo

            if get_in_tf_packet_home "$stage_path"; then #get in packet dir
                mkdir -p "$DIR_META"
                #   echo "#~""$SINGLE_LABEL" >"$IN_SINGLE_ECHO_FILE"
                draft_tfvars_from_packet_variables
                tune_tfvars_for_workflow "$SINGLE_INIT_FILE"
                export_vars_to_env "$TF_VARS" # export_vars_to_env "$TF_VARS"

                terraform workspace select -or-create "$WS_NAME"
                case $RUN_MODE in
                "init")
                    echo "----------------------- Run TERRAFORM init ---------------------------------"
                    terraform init --upgrade
                    ;;
                "plan")
                    echo "----------------------- Run TERRAFORM init ---------------------------------"
                    if terraform init --upgrade; then
                        echo "----------------------- Run TERRAFORM plan ---------------------------------"
                        terraform plan
                    fi
                    ;;
                "apply" | "gitops")
                    touch "$FLAG_LOCK"
                    echo "------------------ Refresh TERRAFORM with init -----------------------------"
                    if terraform init --upgrade; then
                        echo "---------------------- Run TERRAFORM apply ---------------------------------"
                        terraform apply -auto-approve
                        TF_EC=$?
                        [ "$TF_EC" -eq 1 ] && finish_grace "err_tf" "$STAGE_COUNT" "$stage_path"
                        export_vars_to_env "$SINGLE_INIT_FILE"
                    fi
                    ;;
                esac
                echo "----------------------------------------------------------------------------"
                cd "$DIR_ALBUM_HOME" || exit #return from packet to album level

            else
                if [ "$RUN_MODE" = "apply" ] || [ "$RUN_MODE" = "gitops" ]; then
                    case $(test_exec_packet_home "$stage_path") in
                    "SH")
                        echo "This SHELL packet!!!"
                        cd "$DIR_ALBUM_HOME" || exit
                        ;;
                    "ANS")
                        echo "This ANSIBLE packet!!!"
                        cd "$DIR_ALBUM_HOME" || exit
                        ;;
                    "K8S")
                        echo "This KUBECTL packet!!!"
                        cd "$DIR_ALBUM_HOME" || exit
                        ;;
                    "HELM")
                        echo "This HELM packet!!!"
                        cd "$DIR_ALBUM_HOME" || exit
                        ;;
                    *) echo "This UNKNOWN packet!!!" ;;
                    esac
                    export_vars_to_env "$SINGLE_INIT_FILE"
                fi
            fi
            ((STAGE_COUNT++))
        done
        [ -f "$FLAG_LOCK" ] && rm -f "$FLAG_LOCK"
        [ -f "$FLAG_ERR" ] && rm -f "$FLAG_ERR"
        touch "$FLAG_OK"
    done
    ;;
*)
    #show_run_parameters $0 $1 $2 $3 $4
    ;;
esac
unset ANSIBLE_HOST_KEY_CHECKING
cd "$START_POINT" || exit
