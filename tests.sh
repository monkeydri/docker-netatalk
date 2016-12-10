#!/usr/local/bin/bash
###!/bin/bash

echo $BASH_VERSION

DEBUG=1
TEST=1

# declare netatalk
#netatalk='/home/your_user/petsc-3.2-p6/petsc-arch/bin/mpiexec'
#enable -n netatalk
# shopt -s expand_aliases  # Enables alias expansion.
# alias netatalk='echo'
# netatalk "hello"
source docker-entrypoint.sh # > /dev/null 2>&1

conf_file_path="afp-test.conf"
user_file_path="users-test.json"

echo "__________________________"
echo "_________TESTING__________"
echo "__________________________"


# parseConf
# parseUsers
# getValue
# getAllSectionsBut
# getOrdinarySections
# createUsers
# setDirOwner
# setupVolumes

# parseConf
parseConf ${conf_file_path}

# sections() verification
echo "all the sections are :"
for section in "${sections[@]}"; do echo "[${section}]"; done
echo ""
# expected result :

# section_params() verification
echo "params for all sections are :"
for key in "${!section_params[@]}"; do echo "key {${key}} ===> value '${section_params[$key]}'"; done
echo ""
# expected result :


# parseUsers
parseUsers "${user_file_path}"

# users() verification
echo "the users are :"
for user in "${users[@]}"; do echo "[${user}]"; done
echo ""
# expected result :

# user_params() verification
echo "params for all users are :"
for key in "${!user_params[@]}"; do echo "key {${key}} ===> value '${user_params[$key]}'"; done
echo ""
# expected result :


# getSectionParams
# test_section="Share1"
# getSectionParams "${test_section}"
# echo "params for section ${test_section} are :"
# for key in "${!get_param_results[@]}"; do echo "key {${key}} ===> value '${get_param_results[$key]}'"; done
# echo ""

# getValue
# get value of param (for a section or a user) - getValue {prefix} {thing} {param name}
test_user="user1"
test_param="password"
test_value=$(getValue "user" "${test_user}" "${test_param}")
echo "value for user [${test_user}] and param {${test_param}} is '${test_value}'"
echo ""
# expected result : abcdefghijkl01


test_section="Share1"
test_param="path"
test_value=$(getValue "section" "${test_section}" "${test_param}")
echo "value for section [${test_section}] and param {${test_param}} is : '${test_value}'"
echo ""
# expected result : /media/share/share1


# getAllSectionsBut
sections_to_filter="'Global' 'Time Machine' 'Non existing'"
eval getAllSectionsBut $sections_to_filter
echo "filtered sections are :"
for filtered_section in "${filtered_sections[@]}"; do echo "${filtered_section}"; done
echo ""
# expected result : backup Share1 CommonShare


# getOrdinarySections
eval getOrdinarySections $sections_to_filter
echo "ordinary sections are :"
for filtered_section in "${filtered_sections[@]}"; do echo "${filtered_section}"; done
echo ""
# expected result : backup Share1 CommonShare Time Machine




# createUsers
createUsers
#TODO : compare command to be evaled with expected command that should be run.
#TODO TEST CAN ONLY BE PERFORMED IF USERS CORRECTLY PARSED


# example of users created in container after command is ran
# root@brix:/# cat /etc/passwd
# root:x:0:0:root:/root:/bin/bash
# daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
# www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
# backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
# user1:x:555:555:,,,:/home/user1:/bin/bash
# user2:x:556:556:,,,:/home/user2:/bin/bash
# user3:x:557:555:,,,:/home/user3:/bin/bash

# example of groups created in container after command is ran
# root@brix:/media/share# cat /etc/group
# root:x:0:
# www-data:x:33:
# backup:x:34:
# user1:x:555:
# user2:x:556:
# commonshare_group:x:1000:user1,user2
# timemachine_group:x:1001:user1,user2


# setDirOwner
# TODO : TEST CAN ONLY BE PERFORMED IF SECTIONS CORRECTLY PARSED AND USERS CORRECTLY CREATED
TEST_DIR=1 #commands cannot be ran on mac
test_dir="test_dir"
test_users="user1 user2 user3"
#test_users="'user1' 'user2' 'Non user3'"
setDirOwner $test_dir $test_users
#TODO : compare command to be evaled with expected command that should be run.
#TODO : check output of ls -ld $test_dir if TEST_DIR not set

# ls -ld $test_dir ?
# expected result = drwxrwxr-x 2 user1 test_dir_group
# also list group users

# example of directories created in container after command is ran
# root@brix:/media# ls -l
# drwxr-xr-x 4 user2 root 4096 Dec  1 23:52 backup => OK valid users is user2
# drwxr-xr-x 3 root  root 4096 Dec 12 11:34 share
# drwxrwxr-x 2 user1 timemachine_group 4096 Dec 12 15:29 timemachine => OK users 1 and 2
# root@brix:/media/share# ls -l
# drwxrwxr-x 2 user1 commonshare_group 4096 Dec 12 12:45 commonshare => OK users 1 and 2
# drwxr-xr-x 2 user1 root              4096 Dec 12 11:34 share1 => OK valid users is user1


# setupVolumes
setupVolumes
#TODO : TEST CAN ONLY BE PERFORMED IF SECTIONS CORRECTLY PARSED AND USERS CORRECTLY CREATED (and setDirPerm does not fail)
#TODO : compare command to be evaled with expected command that should be run.
