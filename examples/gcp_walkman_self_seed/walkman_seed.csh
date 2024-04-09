#!/usr/local/bin/cw4d
#################################################################################################
#   "BASHCL" play with TERRAFORM & ANSIBLE in old-fashion BASH-style
#################################################################################################
run@@@ = apply # possible here ( or|and in SHEBANG) are: validate, init, apply, destroy, new
debug@@@ = 2   # possible here are 0, 1, 2, 3

# ROOT
project_id="foxy-test-415019"
region="europe-west6"
zone="$region-b"
vpc_name="walkman-managed-vpc"

~WALKMAN_SELF_SEED:
project_id=@@last
region=@@last
vpc_name=@@last
ssh_key_public=@@meta/public.key
ssh_key_private=@@meta/private.key
zone=@@last
machine_type="n2-standard-2"
ssh_user=@@
ssh_key_public=@@meta/public.key
ssh_key_private=@@meta/private.key
startup_script=@@meta/init.sh
<<<SET_access_artefacts | nat_ip | $ssh_user | $ssh_key_private
