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
IN_BASH=0
ANSIBLE_TARGET=all
ANSIBLE_WORKDIR='$HOME'
ANSIBLE_USER=$(whoami)
ANSIBLE_GROUP=$(whoami)
ANSIBLE_ENTRYPOINT="nginx"
#ANSIBLE_ARG=""

check_ansible_connection() {
    local group=${1:-"all"}
    local delay=${2:-"30"}
    local tmp
    tmp=$(mktemp -d)/tmp.yaml
    cat <<EOF >"$tmp"
- hosts: $group
  gather_facts: no
  tasks:
  - name: Wait for hosts become reachable
    ansible.builtin.wait_for_connection:
      timeout: $delay
EOF
    ansible-playbook -i "$ALBUM_SELF" "$tmp"
    rm -r "$(dirname "$tmp")"
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
    #echo "NULL"
    cd "$stored_path" || exit
    return 1
}

#============== A
do_ADD() { # Docker ADD analogue
    [ -z "$1" ] && return
    local src=$1
    local dst=$2
    local usr
    local grp
    local mode
    local tmp
    tmp=$(mktemp -d)/tmp.yaml

    [ -n "$4" ] && mode=$4
    case $3 in
    *":"*)
        usr=$(echo "$3" | cut -d ':' -f 1)
        grp=$(echo "$3" | cut -d ':' -f 2)
        ;;
    [0-9][0-9][0-9]*)
        mode=$3
        usr=$ANSIBLE_USER
        grp=$ANSIBLE_GROUP
        ;;
    "")
        usr=$ANSIBLE_USER
        grp=$ANSIBLE_GROUP
        ;;
    *)
        usr=$3
        grp=$3
        ;;
    esac

    echo "%%%%%%%%%%% remotely: Content ADD/COPY %%%%%%%%%%%%%"
    cat <<EOF >"$tmp"
- hosts: $ANSIBLE_TARGET
  become: yes
  tasks:
EOF
    case $src in
    # for any archived source
    *".zip" | *".tar.gz" | *".tgz")
        do_PACKAGE zip unzip tar >/dev/null
        do_VOLUME "$dst" "$usr:$grp" 0755 >/dev/null
        cat <<EOF >>"$tmp"
  - name: ADD archived
    ansible.builtin.unarchive:
      src: $src
      dest: $dst
EOF
        [[ $src =~ "://" ]] && echo "      remote_src: yes" >>"$tmp"
        ;;
        # for git source
    *".git")
        do_VOLUME "$(dirname "$dst")" "$usr:$grp" 0755 >/dev/null
        cat <<EOF >>"$tmp"
  - name: GIT remote 
    ansible.builtin.git:
      repo: $src
      dest: $dst
EOF
        ;;
    *"://"*)
        do_VOLUME "$(dirname "$dst")" "$usr:$grp" 0755 >/dev/null
        cat <<EOF >>"$tmp"
  - name: ADD remote 
    ansible.builtin.get_url:
      url: $src
      dest: $dst
EOF
        ;;
    *)
        cat <<EOF >>"$tmp"
  - name: ADD local content 
    ansible.builtin.copy:
      src: $src
      dest: $dst
EOF
        ;;
    esac

    [ -n "$usr" ] && echo "      owner: $usr" >>"$tmp"
    [ -n "$grp" ] && echo "      group: $grp" >>"$tmp"
    [ -n "$mode" ] && echo "      mode: $mode" >>"$tmp"
    ansible-playbook "$tmp" -i "$ALBUM_SELF" | grep -v "^TASK \|^PLAY \|^[[:space:]]*$\|ok" | grep -v '""'
    grep <"$tmp" "src\|dest\|repo\|mode\|owner\|group\|url" | tr -d ' '
    rm -r "$(dirname "$tmp")"
    echo -e
}

do_ARG() { # Docker ARG analogue

    [ -z "$1" ] && return
    #  ANSIBLE_ARG=$1
}
#============== C
do_COPY() { # Docker COPY analogue
    do_ADD "$@"
}
#============== D
#============== E
do_ENTRYPOINT() { # Docker ENTRYPOINT analogue
    [ -z "$1" ] && return
    ANSIBLE_ENTRYPOINT=$1
}

do_ENV() { # Docker ENV analogue
    [ -z "$1" ] && return
    [ -z "$ANSIBLE_ENTRYPOINT" ] && return
    local tmp
    local tmp_env
    tmp=$(mktemp -d)
    tmp_env=$tmp/tmp.env
    tmp=$tmp/tmp.yaml

    for param in "$@"; do
        if [[ $param =~ "=" ]]; then
            echo "$param" | sed 's/=/="/;s/$/"/' >>"$tmp_env"
        else
            [ -s "$param" ] && cat "$param" >>"$tmp_env"
        fi
    done
    echo "%%%%%%%%%%% remotely: Entrypoint ENV %%%%%%%%%%%%%%%"
    do_VOLUME "/etc/systemd/system/$ANSIBLE_ENTRYPOINT.service.d" "root:root" 0755 >/dev/null
    do_VOLUME "/etc/env.walkman" "root:root" 0755 >/dev/null
    cat <<EOF >"$tmp"
- hosts: $ANSIBLE_TARGET
  gather_facts: no
  become: yes
  tasks:
  - name: copy CONF file 
    ansible.builtin.copy:
      dest: /etc/systemd/system/$ANSIBLE_ENTRYPOINT.service.d/local.conf
      owner: root
      group: root
      mode: 0444
      content: |
         [Service]
         EnvironmentFile=/etc/env.walkman/$ANSIBLE_ENTRYPOINT.env
  - name: copy ENV file 
    ansible.builtin.copy:
      src: $tmp_env
      dest: /etc/env.walkman/$ANSIBLE_ENTRYPOINT.env
      owner: root
      group: root
      mode: 0444
  - name: Restart $ANSIBLE_ENTRYPOINT
    ansible.builtin.systemd_service:
      state: restarted
      daemon_reload: true
      name: $ANSIBLE_ENTRYPOINT
EOF
    ansible-playbook "$tmp" -i "$ALBUM_SELF" | grep -v "^TASK \|^PLAY \|rescued=\|^[[:space:]]*$\|^changed" | grep -v '""' | sort -u | sed 's/^ok/Target/'
    echo "Entrypoint: [$ANSIBLE_ENTRYPOINT] Environment:"
    cut <"$tmp_env" -d "=" -f 1 | sed 's/^/[/;s/$/]/'
    echo -e

    rm -r "$(dirname "$tmp")"
}
#============== F
do_FROM() { # Docker FROM analogue
    ANSIBLE_TARGET=all
    [ -n "$1" ] && ANSIBLE_TARGET=$1
    echo "%%%%%%%%%%% remotely: FROM - $ANSIBLE_TARGET %%%%%%%%%%%%%%%"
    check_ansible_connection "$ANSIBLE_TARGET" | grep -v "^TASK \|^PLAY \|rescued=\|^[[:space:]]*$" | sed 's/^ok/Target ready/'
    echo -e
}

#============== H
do_HELM() { # helm Wrapper
    [ -z "$1" ] && return
    [ "$1" = "test" ] && return
    echo "%%%%%%%%%%% remotely: HELM %%%%%%%%%%%%%%%"
    helm "$@"
    echo -e
}
#============== K
do_KUBECTL() { # kubectl Wrapper
    [ -z "$1" ] && return
    [ "$1" = "test" ] && return
    echo "%%%%%%%%%%% remotely: KUBECTL %%%%%%%%%%%%%%%"
    kubectl "$@"
    echo -e
}
#============== P
do_PACKAGE() { # rpm/apt/zipper Wrapper
    [ -z "$1" ] && return
    echo "%%%%%%%%%%% remotely: Install PACKAGE(s)  %%%%%%%%%%%"
    local tmp
    tmp=$(mktemp -d)/tmp.yaml
    cat <<EOF >"$tmp"
- hosts: $ANSIBLE_TARGET
  become: true
  tasks:
  - name: APT update
    ansible.builtin.apt:
      update_cache: yes
    when: ansible_os_family == 'Debian' or ansible_os_family == 'Ubuntu'
EOF
    for pkg in "$@"; do
        cat <<EOF >>"$tmp"
  - name: install $pkg
    block:
      - name: $pkg
        ansible.builtin.package:
          state: present
          name: $pkg
        when: ansible_os_family == 'RedHat'
    
      - name: $pkg
        ansible.builtin.apt:
          state: present
          name: $pkg
        when: ansible_os_family == 'Debian' or ansible_os_family == 'Ubuntu'
    
      - name: $pkg
        community.general.zypper:
          state: present
          disable_recommends: false
          name: $pkg
        when: ansible_os_family == 'Suse'
    become: true
    ignore_errors: true
EOF
    done

    ansible-playbook "$tmp" -i "$ALBUM_SELF" | grep -v "^[[:space:]]*$" | grep -v '""' | sed '/\*$/N;s/\n/\t/;s/\*//g;s/TASK //' | tr -s " " | grep -v "skipping:\|\[Gathering \|\[APT\|rescued=\|^ok"
    # cat "$tmp"
    rm -r "$(dirname "$tmp")"
    echo -e
}

do_PLAY() { # ansible Wrapper
    [ -z "$1" ] && return
    [ "$1" = "test" ] && return
    echo "%%%%%%%%%%% remotely: PLAY: $1 %%%%%%%%%%%%%%%"
    ansible-playbook "$1" -i "$ALBUM_SELF" | grep -v "^PLAY \|^[[:space:]]*$"
}
#============== R
do_RUN() { # Docker RUN analogue
    [ -z "$1" ] && return
    local tmp
    local tmp_sh
    tmp=$(mktemp -d)
    tmp_sh=$tmp/tmp.sh

    echo "%%%%%%%%%%% remotely: Script RUN %%%%%%%%%%%"
    {
        echo "#!/bin/bash"
        echo "$@"
    } >>"$tmp_sh"

    tmp=$tmp/tmp.yaml
    cat <<EOF >"$tmp"
- hosts: $ANSIBLE_TARGET
  gather_facts: no
  tasks:
  - name: commands RUN 
    ansible.builtin.script:
     chdir: $ANSIBLE_WORKDIR 
     cmd: $tmp_sh
    register: out
  - debug: var=out.stdout_lines
EOF
    ansible-playbook "$tmp" -i "$ALBUM_SELF" | grep -v "^TASK \|^PLAY \|rescued=\|^changed" | sed 's/^ok/Target/;s/^[ \t]*//;s/[ \t]*$//; s/^"//;s/",$//;s/"$//;s/^\]//;s/}//' | grep -v '""\|^[[:space:]]*$'
    rm -r "$(dirname "$tmp")"
    echo -e
}
#============== S
do_SYNC() { # rsync Wrapper
    [ -z "$1" ] && return
    [ "$1" = "test" ] && return
    echo "%%%%%%%%%%% remotely: RSYNC %%%%%%%%%%%%%%%"
    rsync "$@"
    echo -e
}
#============== T
do_TARGET() { # create ssh access artefacts for target
    [ -z "$1" ] && return
    [ -z "$STAGE_LABEL" ] && return
    local ips='[]'
    local user=$2
    local secret=$3
    echo "%%%%%%%%%%% remotely: Init TARGET for Setup %%%%%%%%%%%"

    ANSIBLE_USER=$user
    ANSIBLE_GROUP=$user
    ips="$(extract_ip_from_state_file "$1")"
    cat <<EOF >"$STAGE_TARGET_FILE"
#!/bin/bash
# ~$STAGE_LABEL
# hosts:$ips
KEY_FILE=$secret
EOF

    print_hosts_for_list_request "$ips" "$user" "$secret": >>"$INVENTORY_LIST_HEAD"

    for ip in $(echo "$ips" | sed 's/,/ /;s/\[//;s/\]//'); do
        # shellcheck disable=SC2016
        echo 'ssh  -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i $KEY_FILE '"$user"'@'"$ip" >>"$STAGE_TARGET_FILE"
        print_hostvars_for_host_request "$ip" "$user" "$secret" >>"$INVENTORY_HOST"
        print_hostvars_for_list_request "$ip" "$user" "$secret" >>"$INVENTORY_LIST_TAIL"
    done

    chmod 777 "$STAGE_TARGET_FILE"
    echo "Available targets: $ips"
    echo -e
}
#============== U
do_USER() { # Docker USER analogue
    [ -z "$1" ] && return
    if [[ $1 =~ ":" ]]; then
        ANSIBLE_USER=$(echo "$1" | cut -d ':' -f 1)
        ANSIBLE_GROUP=$(echo "$1" | cut -d ':' -f 2)
    else
        ANSIBLE_USER=$1
        ANSIBLE_GROUP=$1
    fi
}
#============== V
do_VOLUME() { # Docker VOLUME analogue
    [ -z "$1" ] && return
    local dir=$1
    local usr
    local grp
    local mode="'0755'"
    local tmp
    tmp=$(mktemp -d)/tmp.yaml

    [ -n "$3" ] && mode=$3
    case $2 in
    *":"*)
        usr=$(echo "$2" | cut -d ':' -f 1)
        grp=$(echo "$2" | cut -d ':' -f 2)
        ;;
    [0-9][0-9][0-9]*)
        mode=$3
        usr=$ANSIBLE_USER
        grp=$ANSIBLE_GROUP
        ;;
    "")
        usr=$ANSIBLE_USER
        grp=$ANSIBLE_GROUP
        ;;
    *)
        usr=$2
        grp=$2
        ;;
    esac

    echo "%%%%%%%%%%% remotely: Create VOLUME(directory) %%%%%%%%%%%%%"
    cat <<EOF >"$tmp"
- hosts: $ANSIBLE_TARGET
  become: yes
  tasks:
  - name: Create DIRECTORY
    ansible.builtin.file:
      path:  $dir
      state: directory
      mode: $mode
      owner: $usr
      group: $grp
EOF
    ansible-playbook "$tmp" -i "$ALBUM_SELF" | grep -v "^TASK \|^PLAY \|rescued=\|^[[:space:]]*$" | grep -v '""'
    rm -r "$(dirname "$tmp")"
    echo -e
}
#============== W
do_WALKMAN() { # Walkman installer
    [ "$1" = "test" ] && return
    echo "%%%%%%%%%%% remotely: WALKMAN INSTALL %%%%%%%%%%%%%%%"
    sed <"$STAGE_TARGET_FILE" 's/^ssh /cw4d.sh /' | bash
    echo -e
}

do_WORKDIR() { # Docker WORKDIR analogue
    if [ -z "$1" ]; then
        ANSIBLE_WORKDIR='$HOME'
    else
        ANSIBLE_WORKDIR=$1
    fi

}

############### HELPERS EXECUTOR ##############
run_helper_by_name() {
    local helper_call_string
    local val
    local helper_name
    local helper_params

    case $2 in
    "<<<"*)
        helper_call_string="$(echo "$2" | tr -d ' ' | sed 's/<<<//; s/|/ /g;')"
        ;;
    "do_"[A-Z]*)
        helper_call_string=$2
        ;;
    ^\$\(*)
        helper_call_string="$(echo "$2" | cut -d'(' -f 2 | cut -d ')' -f 1)"
        ;;
    *) return ;;
    esac

    helper_name="$(echo "$helper_call_string" | awk '{print $1}')"
    # shellcheck disable=SC2001
    helper_params="$(echo "$helper_call_string" | sed "s/^$helper_name//")"

    if helper_exists "$helper_name"; then
        if [[ "$1" =~ ^do_* ]]; then
            [[ "$3" =~ "env_after" ]] && case $helper_name in
            do_RUN) do_RUN "${helper_params}" ;;
            *) eval "$helper_name $helper_params" ;;
            esac
        else
            [ -n "$1" ] && val="$(eval "$helper_call_string")"
            [[ "$3" =~ "env" ]] && export CW4D_"$1"="$(eval echo "$val")" #$val
        fi

        [[ "$1" != "$helper_name" ]] && [[ "$3" =~ "file" ]] && add_or_replace_var "$1" "$val"
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
        # shellcheck disable=SC2001
        tail=$(echo "$val" | sed 's/.*[0-9]//g')
        # shellcheck disable=SC2001
        head=$(echo "$val" | sed "s/$tail//")

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

get_if_exported() {
    if export | grep -q "$ENV_PREFIX$1"; then
        # shellcheck disable=SC2005
        echo "$(eval echo '$'"$ENV_PREFIX$1")"
    fi
}

get_terraform_output_value() {
    local output
    output=$(echo "$1" | cut -d '/' -f 2)
    output=$(terraform output -raw -compact-warnings "$output" 2>/dev/null | awk '/Warnings/ {exit} {print}')
    [ -n "$output" ] && echo "$output" && return
    echo ""
}

init_bash_inline_vars() {
    echo "#!/bin/bash" >"$BASH_INLINE"
    # shellcheck disable=SC2016
    echo 'set_before=$( set -o posix; set | sed -e "/^_=*/d" )' >>"$BASH_INLINE"
    chmod +x "$BASH_INLINE"
    export | grep $ENV_PREFIX | sed "s/^declare -x //;s/$ENV_PREFIX//" | grep -v "NaN" | grep -v '""' >>"$BASH_INLINE"
}

run_bash_inlined_part() {
    echo "%%%%%%%%%%%% locally: RUN INLINED BASH  %%%%%%%%%%%%"
    # echo "mode:$2"
    /bin/bash "$BASH_INLINE"
    set -o allexport
    # shellcheck source=/dev/null
    . /tmp/walkman_bash_export.tmp
    set +o allexport
    echo -e
}

inlines_engine() {
    [ "$IN_BASH" -eq 3 ] && IN_BASH=0
    [ "$IN_BASH" -eq 1 ] && IN_BASH=2
    if [[ $2 =~ ^\/\* ]]; then
        IN_BASH=1
        init_bash_inline_vars
    fi
    if [[ $2 =~ ^\*\/ ]]; then
        IN_BASH=3
        # shellcheck disable=SC2016
        {
            echo 'set_after=$( set -o posix; unset set_before; set | sed -e "/^_=/d" )'
            echo 'diff  <(echo "$set_before") <(echo "$set_after") | sed -e "s/^> //" -e "/^[[:digit:]].*/d" | sed "s/^/CW4D_/" > /tmp/walkman_bash_export.tmp'
        } >>"$BASH_INLINE"

        if [ "$1" -ge 2 ]; then
            if [ "$3" = "env_all" ] || [ "$3" = "env_file" ]; then
                run_bash_inlined_part "$1" "$3"
            fi
        else
            if [ "$3" = "env_all" ] || [ "$3" = "env_after" ]; then
                run_bash_inlined_part "$1" "$3"
            fi
        fi
        [ "$DEBUG" -ge 3 ] && echo "======== in ENV vars AFTER inlines:=========" && export | grep $ENV_PREFIX | sed "s/^declare -x //;s/$ENV_PREFIX//" && echo -e
    fi
    [ "$IN_BASH" -eq 2 ] && echo "$2" >>"$BASH_INLINE"
}

bashcl_translator() {
    inlines_engine "$@"
    [ "$IN_BASH" -ge 1 ] && return

    local key_val
    local key
    local val
    local last
    local tmp
    local is_var

    key_val=$(echo "$2" | grep -v '""' | sed 's/=~/=/;s/,~/,/;s/@@all/all/g' | tr '$' '\0' | sed "s/\o0[A-Za-z]/$ENV_PREFIX&/g" | sed "s/$ENV_PREFIX\o0/\o0$ENV_PREFIX/g" | tr '\0' '$' | tr -d '"')
    [ -z "$key_val" ] && return

    case $key_val in
    "<<<"*)
        key=$(echo "$key_val" | cut -d '|' -f 1 | tr -d ' ' | sed 's/^<<<//')
        val=$key_val
        ;;
    "do_"[A-Z]*)
        key=$(echo "$key_val" | awk '{print $1}')
        val=$key_val
        ;;
    ^\$\(*)
        key=$(echo "$key_val" | cut -d '(' -f 2 | awk '{print $1}')
        val=$key_val
        ;;
    *)
        key=$(echo "$key_val" | sed 's/=/\o0/' | cut -d $'\000' -f 1)
        val=$(echo "$key_val" | sed 's/=/\o0/' | cut -d $'\000' -f 2)
        is_var=1
        ;;
    esac

    echo "$val" | grep -q ':' || val=$(echo "$val" | sed 's/^{/[/; s/}$/]/;') # set correct type brakets for list type

    last=$(get_if_exported "$key")
    case $val in
    *"@@self"*)
        tmp=$(get_terraform_output_value "$key")
        val=${val//@@self/$tmp}
        ;&
    *"@@")
        tmp=$(grep <"$VARS_TF" "variable\|default" | sed ':a;N;$!ba;s/{\n/#/g' | tr -d ' ' | sed 's/variable"//;s/"//g' | grep "^$key" | sed 's/=/\o0/' | cut -d $'\000' -f 2)
        val=${val//@@/$tmp}
        ;&
    *"@@last"*)
        val=${val//@@last/$last}
        ;&
    *"++last"*)
        # [ -n "$last" ] && last=$(increment_if_possible "$last")
        val=${val//++last/$last}
        ;&
    *"@@meta"*)
        tmp=$(readlink -f ../.meta)
        [ -z "$STAGE_LABEL" ] && tmp=$DIR_ALBUM_HOME/.meta
        val=${val//@@meta/$tmp}
        ;&
    "{"* | "["*)
        val=$(echo "$val" | sed 's/^{ */{/;s/ *}$/}/; s/^\[ */[/;s/ *\]$/]/; s/, */,/g; s/ *,/,/g')
        ;&
    *)
        # shellcheck disable=SC2076 disable=SC2016
        if [ -z "$is_var" ]; then
            run_helper_by_name "$key" "$val" "$3"
        else
            val="$(eval echo "$val")"
            [ -z "$val" ] && return
            val=$(echo "$val" | sed 's/^/"/;  s/$/"/; ')

            [[ "$3" =~ "env" ]] && export CW4D_"$key"="$(eval echo "$val")"
            [[ ! $key_val =~ "@@self" ]] && [[ "$3" =~ "file" ]] && add_or_replace_var "$key" "$val"
        fi
        ;;
    esac
}

############# VARs PROCESSING #################
add_or_replace_var() {
    local key=$1
    local val=$2
    if grep -Fq "$key=" "$TF_VARS"; then # REPLACE values for existed keys
        sed -i "/^$key=/c $key=$val" "$TF_VARS"
    else # ADD new key-value pairs
        grep <"$VARS_TF" "variable" | cut -d '"' -f 2 | grep -q "^$key$" && echo "$key=$val" >>"$TF_VARS"
    fi
    # post tune structures in tfvars
    sed -i 's/="\[/=\["/g; s/\]"/"\]/g; s/="{/={"/g; s/}"/"}/g' "$TF_VARS"
    sed -i 's/\,/"\,"/g; s/\:/"\:"/g; s/""/"/g; s/"\:"\/\//\:\/\//g' "$TF_VARS"
}

update_variables_state() {
    local rest
    [ "$DEBUG" -ge 2 ] && echo "======== in ENV vars BEFORE stage tune:=========" && export | grep $ENV_PREFIX | sed "s/^declare -x //;s/$ENV_PREFIX//" && echo -e
    rest=$(wc -l < <(sed <"$1" 's/#.*$//;/^$/d' | grep -v '^~'))
    while IFS= read -r key_val; do
        bashcl_translator "$rest" "$key_val" "$2"
        ((rest--))
    done < <(sed <"$1" 's/#.*$//;/^$/d' | grep -v '^~')

    [ "$IN_BASH" -ge 1 ] && IN_BASH=0
    [ "$DEBUG" -ge 2 ] && [ -n "$2" ] && echo "======== in ENV vars AFTER stage tune:=========" && export | grep $ENV_PREFIX | sed "s/^declare -x //;s/$ENV_PREFIX//" && echo -e
    [ "$DEBUG" -ge 2 ] && [ -z "$2" ] && echo "================ TUNED tvfars: ================" && cat "$TF_VARS" && echo -e
}

draft_tfvars_from_packet_variables() {
    #  create ENV-based part of dynamic tfvars (lookup in packet variables.tf for each variable and assign its value from corresponding ENV var)
    grep <"$VARS_TF" '{' | grep variable | sed 's/"//g' | awk -v val="$ENV_PREFIX" '{print "echo " $2 "=$" val $2  }' | bash | sed 's/=/="/g' | sed 's/$/"/' | grep -v '""' >"$TF_VARS"
    [ "$DEBUG" -ge 1 ] && echo "=============== DRAFTED tvfars: ===================" && cat "$TF_VARS" && echo -e
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
    hosts=${1//\"/}
    [ "$hosts" = "[]" ] && return
    hosts=$(echo "$hosts" | sed 's/\[/\["/;s/\]/"\]/; s/,/","/g')
    echo -n "\"$STAGE_LABEL\":{"
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
        BASH_INLINE="$DIR_WS_TMP/bash_inline.sh"
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
    PLAYBOOK_HELPER=$PACK_HOME_FULL_PATH/playbook.yaml
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
    local grp=$1
    [ -z "$1" ] && return
    [ "$1" = "root" ] && return
    not_installed zypper || grp="users"
    [ -d "/home/$1" ] && try_as_root chown -R "$1":"$grp" "/home/$1"
}

not_installed() {
    for item in "$@"; do
        [ -z "$(which "$item" 2>/dev/null)" ] && return 0
    done
    return 1
}

build_shc() {
    local tmp
    not_installed shc || return
    tmp=$(mktemp -d)
    git clone https://github.com/neurobin/shc.git "$tmp"
    cd "$tmp" || exit
    ./autogen.sh
    ./configure
    make
    try_as_root make install
    try_as_root mv /usr/local/bin/shc /usr/bin/shc
    cd "$HOME" || exit
    rm -rf "$tmp"
}

os_detect() {

    if grep </etc/os-release -q "CentOS"; then
        grep </etc/os-release -q "Stream 9" && echo "CENTOS-9" && return
        grep </etc/os-release -q "Stream 8" && echo "CENTOS-8" && return
        grep </etc/os-release -q "Linux 7" && echo "CENTOS-7" && return
    fi

    if grep </etc/os-release -q "Rocky Linux"; then
        grep </etc/os-release -q "Linux 9" && echo "ROCKY-9" && return
        grep </etc/os-release -q "Linux 8" && echo "ROCKY-8" && return
        grep </etc/os-release -q "Linux 7" && echo "ROCKY-7" && return
    fi

    if grep </etc/os-release -q "Red Hat"; then
        grep </etc/os-release -q "Linux 9" && echo "RHEL-9" && return
        grep </etc/os-release -q "Linux 8" && echo "RHEL-8" && return
        grep </etc/os-release -q "Linux Server 7" && echo "RHEL-7" && return
    fi

    if grep </etc/os-release -q "Amazon Linux"; then
        grep </etc/os-release -q "2023" && echo "AMAZON-2023" && return
        echo "AMAZON-2" && return
    fi
    if grep </etc/os-release -q "SLES"; then
        grep </etc/os-release -q "Server 15" && echo "SLES-15" && return
        echo "SLES-14" && return
    fi

    if grep </etc/os-release -q "openSUSE"; then
        grep </etc/os-release -q "Leap 15" && echo "SUSE-15" && return
        echo "SUSE-14" && return
    fi

}

apt_packages_install() {

    not_installed apt && return
    local command
    echo "update repositories list"
    try_as_root DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null
    # shellcheck disable=SC2046
    not_installed pipx && try_as_root apt-get install -y pipx >/dev/null 2>&1
    for pkg in "$@"; do
        command=$pkg
        [ "$pkg" = "coreutils" ] && command="csplit"
        [ "$pkg" = "python3-pip" ] && command="pip3"
        if not_installed "$command"; then
            echo "install pkg: $pkg"
            try_as_root DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null
        fi
    done
}

zypper_not_run() {
    #ps -A | grep ypp
    while [ -n "$(pgrep zypper)" ]; do sleep 5; done
    while [ -n "$(pgrep Zypp-main)" ]; do sleep 5; done
}

zypper_packages_install() {
    not_installed zypper && return
    local command
    echo "First system rise delay"
    sleep 15
    zypper_not_run && sleep 5
    [ "$(os_detect)" = "SLES-15" ] && try_as_root zypper addrepo https://download.opensuse.org/repositories/openSUSE:Backports:SLE-15-SP4/standard/openSUSE:Backports:SLE-15-SP4.repo
    zypper_not_run && try_as_root zypper --gpg-auto-import-keys refresh

    for pkg in "$@"; do
        command=$pkg
        [ "$pkg" = "coreutils" ] && command="csplit"
        [ "$pkg" = "python3-pip" ] && command="pip3"
        if not_installed "$command"; then
            echo "install pkg: $pkg"
            zypper_not_run && try_as_root zypper -n install -y "$pkg" >/dev/null 2>&1
        fi
    done
    if [ "$(os_detect)" = "SLES-15" ] || [ "$(os_detect)" = "SUSE-15" ]; then
        try_as_root zypper -n install -y python311 python311-pipx python311-pip
        alias python3=python3.11
    else
        try_as_root zypper -n install -y python3-pip
    fi
}

yum_packages_install() {
    not_installed yum && return
    if not_installed dnf; then
        local command
        case $(os_detect) in

        "AMAZON-2")
            try_as_root amazon-linux-extras install epel -y #for Amazon Linux 2
            ;;
        "AMAZON-2023") ;;
        "RHEL-7")
            export LANG="en_US.UTF-8"
            export LC_CTYPE="en_US.UTF-8"
            try_as_root yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm >/dev/null 2>&1 #RHEL-7
            echo "user.max_user_namespaces=10000" | try_as_root tee /etc/sysctl.d/42-rootless.conf
            try_as_root sysctl --system
            ;;
        "CENTOS-7")
            export LANG="en_US.UTF-8"
            export LC_CTYPE="en_US.UTF-8"
            try_as_root yum -y install epel-release # CENTOS-7
            #echo "user.max_user_namespaces=10000" | try_as_root tee /etc/sysctl.d/42-rootless.conf
            try_as_root sysctl --system
            ;;
        *)
            export LANG="en_US.UTF-8"
            export LC_CTYPE="en_US.UTF-8"
            try_as_root yum -y install epel-release # CENTOS-7
            #echo "user.max_user_namespaces=10000" | try_as_root tee /etc/sysctl.d/42-rootless.conf
            try_as_root sysctl --system
            ;;

        esac

        # shellcheck disable=SC2046
        not_installed pipx && try_as_root yum install -y pipx >/dev/null 2>&1

        for pkg in "$@"; do
            command=$pkg
            [ "$pkg" = "coreutils" ] && command="csplit"
            [ "$pkg" = "python3-pip" ] && command="pip3"
            echo "install pkg: $pkg"
            not_installed "$command" && try_as_root yum install -y "$pkg" >/dev/null 2>&1
        done
    fi
}

dnf_packages_install() {
    not_installed dnf && return
    local command

    case $(os_detect) in
    "CENTOS-8")
        #  try_as_root dnf update -y
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y >/dev/null 2>&1 #CentOS-8
        try_as_root dnf config-manager --set-enabled PowerTools
        ;;
    "CENTOS-9")
        # try_as_root dnf update -y
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y >/dev/null 2>&1 #CentOS-9
        try_as_root dnf config-manager --set-enabled PowerTools
        ;;
    "RHEL-8" | "ROCKY-8")
        #try_as_root dnf update -y
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y >/dev/null 2>&1 #RHEL-8
        ;;
    "RHEL-9")
        #try_as_root dnf update -y
        not_installed subscription-manager || try_as_root subscription-manager repos --enable "codeready-builder-for-rhel-9-$(arch)-rpms"
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y >/dev/null 2>&1 #RHEL-9
        ;;
    "ROCKY-9")
        # try_as_root dnf update -y
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y >/dev/null 2>&1 #ROCKY-9
        ;;

    *)
        #try_as_root dnf update -y
        try_as_root dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y >/dev/null 2>&1 #all other
        ;;
    esac

    # shellcheck disable=SC2046
    not_installed pipx && try_as_root dnf install -y pipx >/dev/null 2>&1

    for pkg in "$@"; do
        command=$pkg
        [ "$pkg" = "coreutils" ] && command="csplit"
        [ "$pkg" = "python3-pip" ] && command="pip3"
        echo "install pkg: $pkg"
        not_installed "$command" && try_as_root dnf install -y -q "$pkg" >/dev/null 2>&1
    done
}

system_pakages_install() {
    if not_installed wget curl pip3 unzip cc shc rsync csplit git mc nano openssl; then
        apt_packages_install wget curl unzip gcc automake shc rsync python3-pip coreutils git tig mc nano openssl

        yum_packages_install wget curl unzip gcc automake shc rsync python3-pip coreutils git tig mc nano openssl
        [ "$(os_detect)" = "RHEL-7" ] && yum_packages_install podman podman-compose

        dnf_packages_install wget curl unzip gcc automake shc rsync python3-pip coreutils git tig mc nano podman openssl

        zypper_packages_install wget curl unzip gcc make automake rsync coreutils git tig mc nano openssl docker
        build_shc
    fi
}

# shellcheck disable=SC2183
# shellcheck disable=SC2046
function ver_cmp {
    printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' ')
}

function py_ver() {
    return "$(python3 --version 2>/dev/null | grep "Python" | awk '{print $NF} ')"
}

init_home_local_bin() {
    local user
    local user_home_local
    local user_home_bin
    local pkg_arch

    [ "$(arch)" = "x86_64" ] && pkg_arch="amd64"
    [[ "$(arch)" =~ "arm64" ]] && pkg_arch="arm64"
    if [ -z "$pkg_arch" ]; then
        echo "!!!!!!! ERROR: UNSUPPORTED CPU ARCHITECTURE !!!!!!!!"
        exit
    fi

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

    if not_installed docker; then
        if not_installed podman; then
            case $(os_detect) in
            "AMAZON-2")
                try_as_root amazon-linux-extras install docker
                try_as_root service docker start
                ;;
            "AMAZON-2023")
                try_as_root yum install -y docker
                try_as_root service docker start
                ;;
            *)
                curl -fsSL https://get.docker.com -o get-docker.sh
                try_as_root sh ./get-docker.sh
                try_as_root systemctl enable /usr/lib/systemd/system/docker.service
                try_as_root systemctl start docker.service
                ;;
            esac

            try_as_root systemctl enable /usr/lib/systemd/system/docker.service
            try_as_root usermod -aG docker "$user"
        else
            try_as_root ln -s "$(which podman)" "$user_home_bin/docker"

            if not_installed podman-compose; then
                try_as_root -H -u "$user" python3 -m pip install --user podman-compose
                try_as_root ln -s "$(which podman-compose)" "$user_home_bin/docker-compose"
            fi
            fix_user_home "$user"
        fi
    else
        if [ ! -L "$(which docker 2>/dev/null)" ]; then
            try_as_root systemctl enable /usr/lib/systemd/system/docker.service
            try_as_root systemctl start docker.service
            try_as_root usermod -aG docker "$user"
        fi
    fi

    if not_installed jq; then
        try_as_root curl -fsSLo "$user_home_bin/jq" https://github.com/jqlang/jq/releases/download/jq-${JQ_v}/jq-linux-${pkg_arch}
        try_as_root chmod +x "$user_home_bin/jq"
    fi

    if not_installed terraform; then
        try_as_root curl -fsSLo "$user_home_bin/terraform_linux_${pkg_arch}.zip" https://releases.hashicorp.com/terraform/${TERRAFORM_v}/terraform_${TERRAFORM_v}_linux_${pkg_arch}.zip
        try_as_root unzip -o "$user_home_bin/terraform_linux_${pkg_arch}.zip" -d "$user_home_bin"
        try_as_root rm -f "$user_home_bin/terraform_linux_${pkg_arch}.zip"
    fi

    if not_installed ansible; then
        try_as_root pip3 install --upgrade pip >/dev/null 2>&1

        if not_installed pipx; then
            if [ "$user" = "$(whoami)" ]; then
                python3 -m pip install --user pipx
            else
                try_as_root -H -u "$user" python3 -m pip install --user pipx
                fix_user_home "$user"
            fi
            python3 -m pipx ensurepath
        fi

        if not_installed pipx; then
            if [ "$user" = "$(whoami)" ]; then
                python3 -m pip install --user ansible-core
            else
                try_as_root -H -u "$user" python3 -m pip install --user ansible-core
                fix_user_home "$user"
            fi
        else
            pipx install ansible-core
        fi

    fi

    if not_installed helm; then
        try_as_root curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    if not_installed kubectl; then
        try_as_root curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${pkg_arch}/kubectl"
        try_as_root chmod +x kubectl
        try_as_root mv ./kubectl "$user_home_bin"/kubectl
        fix_user_home "$user"
    fi

    if not_installed k9s; then
        try_as_root curl -s -L https://github.com/derailed/k9s/releases/download/v${K9S_v}/k9s_Linux_${pkg_arch}.tar.gz | try_as_root tar xvz -C "$user_home_bin"
        try_as_root rm "$user_home_bin/README.md" "$user_home_bin/LICENSE"
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
    if not_installed shc; then
        echo "======================================================================"
        echo "!!!!!!!!!!!!!!!!!! CW4D self-compilation not possible !!!!!!!!!!!!!!!!"
        echo "             SHC compiller not found installation ABORTED"
        echo "======================================================================"
        exit
    else
        local self=$0
        local self_path
        [ -n "$1" ] && self=$1
        self_path=$(dirname "$self")
        echo "======================= CW4D self-compilation ================================"
        try_as_root shc -vrf "$self" -o /usr/local/bin/cw4d
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
    fi
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
            tmp=$(mktemp -d)/tmp.yaml
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
        ssh "$@" "sudo tee /usr/local/bin/cw4d.sh;sudo chmod 777 /usr/local/bin/cw4d.sh;/usr/local/bin/cw4d.sh " <"$0"
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

        grep <"$ALBUM_SELF" -v '@@@' | sed 's/#.*$//;/^$/d' | sed "s/@@this/$WS_NAME/g" >"$ALBUM_VARS_DRAFT"

        sed <"$ALBUM_VARS_DRAFT" 's/^~/###~/' | csplit - -s '/^###~/' '{*}' -f "$DIR_WS_TMP/$WS_NAME" -b "%02d_vars.draft"

        STAGE_COUNT=0
        STAGE_INIT_FILE="$DIR_WS_TMP/$WS_NAME"$(printf %02d $STAGE_COUNT)_vars.draft
        STAGE_LABEL="&root&"
        update_variables_state "$STAGE_INIT_FILE" "env_all"

        STAGE_COUNT=1
        for stage_path in $(
            find "$DIR_ALBUM_HOME" -maxdepth 1 -type d | sort | grep -v '\.meta\|\.git' | tail -n +2
        ); do
            STAGE_INIT_FILE="$DIR_WS_TMP/$WS_NAME"$(printf %02d $STAGE_COUNT)_vars.draft
            STAGE_LABEL=$(head <"$STAGE_INIT_FILE" -n 1 | sed 's/#//g;s/ //g;s/://g;s/~//g;')
            STAGE_TARGET_FILE=$DIR_ALBUM_META/ssh-to-$WS_NAME-$STAGE_LABEL.sh

            echo
            echo "############################## Stage-$STAGE_COUNT ################################"
            echo "### Stage LABEL: $STAGE_LABEL  "
            echo "### Stage HOME: $stage_path"
            echo

            if get_in_tf_packet_home "$stage_path"; then #get in packet dir
                mkdir -p "$DIR_META"
                draft_tfvars_from_packet_variables
                update_variables_state "$STAGE_INIT_FILE" "env_file"

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
                        update_variables_state "$STAGE_INIT_FILE" "env_after"
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
                    update_variables_state "$STAGE_INIT_FILE" "env_all"
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
