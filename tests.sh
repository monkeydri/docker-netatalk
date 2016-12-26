#!/usr/local/bin/bash
###!/bin/bash

echo $BASH_VERSION

# output color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# env vars
DEBUG=1
TEST=1

# tests vars
conf_file_ok_path='tests/afp-test-ok.conf'
conf_file_bad_path='tests/afp-test-bad.conf'
conf_json_ok='[{"name":"Global","log file":"/dev/log","uam list":"uams_guest.so uams_dhx2.so uams_dhx.so"},{"name":"share1","path":"/media/share1","valid users":"user1"},{"name":"share2","path":"/media/share2","valid users":"user1"},{"name":"common","path":"/media/common","valid users":"user1 user2"},{"name":"time machine","path":"/media/timemachine","time machine":"yes","valid users":"user1"}]'
#conf_json_bad=''
users_file_ok_path='tests/users-test-ok.json'
users_file_bad_path='tests/users-test-bad.json'
users_json_ok='[ { "username": "user1", "password": "abcdefghijkl01", "uid": "555", "gid": "555" }, { "username": "user2", "password": "abcdefghijkl01" }, { "username": "user3", "password": "abcdefghijkl01", "uid": "557", "gid": "555" } ]'
users_json_bad='[ { "username": "user1", "password": "abcdefghijkl01", "uid": "555", "gid": "555" }, { "password": "abcdefghijkl01", "uid": "556", "gid": "556" }, { "username": "user3", "password": "abcdefghijkl01", "uid": "557", "gid": "555" } ]'
sections_json_ok='[{"name":"backup","path":"/media/backup","valid users":"user2"},{"name":"Share1","path":"/media/share/share1","valid users":"user1"},{"name":"CommonShare","path":"/media/share/commonshare","valid users":"user1 user2"},{"name":"Time Machine","path":"/media/timemachine","time machine":"yes","valid users":"user1 user2"}]'
sections_json_bad='[{"name":"backup","path":"/media/backup","valid users":"user2"},{"name":"Share1","path":"/media/share/share1","valid users":"user1"},{"name":"CommonShare","path":"/media/share/commonshare","valid users":"user1 user2"},{"name":"backup","path":"/media/timemachine","time machine":"yes","valid users":"user1 user2"}]'
osx_usernames='["nobody","root","daemon","_uucp","_taskgated","_networkd","_installassistant","_lp","_postfix","_scsd","_ces","_mcxalr","_appleevents","_geod","_serialnumberd","_devdocs","_sandbox","_mdnsresponder","_ard","_www","_eppc","_cvs","_svn","_mysql","_sshd","_qtss","_cyrus","_mailman","_appserver","_clamav","_amavisd","_jabber","_appowner","_windowserver","_spotlight","_tokend","_securityagent","_calendar","_teamsserver","_update_sharing","_installer","_atsserver","_ftp","_unknown","_softwareupdate","_coreaudiod","_screensaver","_locationd","_trustevaluationagent","_timezone","_lda","_cvmsroot","_usbmuxd","_dovecot","_dpaudio","_postgres","_krbtgt","_kadmin_admin","_kadmin_changepw","_devicemgr","_webauthserver","_netbios","_warmd","_dovenull","_netstatistics","_avbdeviced","_krb_krbtgt","_krb_kadmin","_krb_changepw","_krb_kerberos","_krb_anonymous","_assetcache"]'

# attempt to bypass netatalk call
# declare netatalk
#netatalk='/home/your_user/petsc-3.2-p6/petsc-arch/bin/mpiexec'
#enable -n netatalk
# shopt -s expand_aliases  # Enables alias expansion.
# alias netatalk='echo'
# netatalk "hello"

source docker-entrypoint.sh # > /dev/null 2>&1

echo "___________________________"
echo "___TESTING parseConfFile___"
echo "___________________________"


conf_json_ok_result=$(parseConfFile "${conf_file_ok_path}")
if [ $? -eq 0 ] && [ "${conf_json_ok_result}" == "${conf_json_ok}" ]; then
   echo -e "${GREEN}test 1 success${NC}"
else
   echo -e "${RED}test 1 fail${NC}"
fi
echo "___________________________"
echo $conf_json_ok_result
echo "___________________________"


# bad conf file : should not fail
conf_json_bad_result=$(parseConfFile "${conf_file_bad_path}")
if [ $? -eq 0 ]; then
   echo -e "${GREEN}test 2 success${NC}"
else
   echo -e "${RED}test 2 fail${NC}"
fi
echo "___________________________"
echo $conf_json_bad_result
echo -e "___________________________\n\n\n"


# echo "___________________________"
# echo "___TESTING getSections_____"
# echo "___________________________"
#
#
# # getSections -> make it function ?
#
# sections_json_ok=$(echo "${conf_json_ok}" | jq 'map(select(.name != "Global" and .name != "Homes" ))' -r -c)
# # expected result : [{"name":"backup","path":"/media/backup","valid users":"user2"},{"name":"Share1","path":"/media/share/share1","valid users":"user1"},{"name":"CommonShare","path":"/media/share/commonshare","valid users":"user1 user2"},{"name":"Time Machine","path":"/media/timemachine","time machine":"yes","valid users":"user1 user2"}]
# if [ "${sections_json_ok}" == '[{"name":"backup","path":"/media/backup","valid users":"user2"},{"name":"Share1","path":"/media/share/share1","valid users":"user1"},{"name":"CommonShare","path":"/media/share/commonshare","valid users":"user1 user2"},{"name":"Time Machine","path":"/media/timemachine","time machine":"yes","valid users":"user1 user2"}]' ]; then
#    echo -e "${GREEN}test 1 success${NC}"
# else
#    echo -e "${RED}test 1 fail${NC}"
# fi
# echo "___________________________"
# echo $sections_json_ok
# echo "___________________________"
#
# # TODO : do some bad stuff on json
# sections_json_bad=$(echo '[{"name":"Global","log file":"/dev/log","uam list":"uams_guest.so uams_dhx2.so uams_dhx.so"},{"name":"backup","path":"/media/backup","valid users":"user2"},{"name":"Share1","path":"/media/share/share1","valid users":"user1"},{"name":"CommonShare","path":"/media/share/commonshare","valid users":"user1 user2"},{"name":"Time Machine","path":"/media/timemachine","time machine":"yes","valid users":"user1 user2"}]' | jq 'map(select(.name != "Global" and .name != "Homes" ))' -r -c)
# if [ $? -eq 0 ]; then
#    echo -e "${RED}test 2 fail${NC}"
# else
#    echo -e "${GREEN}test 2 success${NC}"
# fi
# echo "___________________________"
# # echo $sections_json_bad
# echo -e "___________________________\n\n\n"


echo "____________________________"
echo "_TESTING getSystemUsernames_"
echo "____________________________"

usernames=$(getSystemUsernames)
if [ $? -eq 0 ] && [ "${usernames}" == "${osx_usernames}" ]; then
   echo -e "${GREEN}test 1/1 success${NC}"
else
   echo -e "${RED}test 1/1 fail${NC}"
fi
echo "___________________________"
echo "${usernames}"
echo -e "___________________________\n\n\n"





echo "____________________________"
echo "___TESTING checkSections____"
echo "____________________________"

usernames='["user1","user2","user3"]'
check_sections_ok=$(checkSections "${sections_json_ok}" "${usernames}")
if [ $? -eq 0 ]; then
   echo -e "${GREEN}test 1/2 success${NC}"
else
   echo -e "${RED}test 1/2 fail${NC}"
fi
#echo $check_sections_ok
echo "___________________________"



check_sections_bad=$(checkSections "${sections_json_bad}" "${usernames}")
if [ $? -eq 0 ]; then
   echo -e "${RED}test 2/2 fail${NC}"
else
   echo -e "${GREEN}test 2/2 success${NC}"
fi
echo "___________________________"
# echo $check_sections_bad
echo -e "___________________________\n\n\n"


echo "___________________________"
echo "___TESTING getJsonFile_____"
echo "___________________________"

users_json_ok_result=$(getJsonFile "${users_file_ok_path}")
#if [ ! -z "${users_json_ok}" ]; then
# if [ $? -eq 0 ] && [ "${users_json_ok}"=="3" ]; then
if [ $? -eq 0 ] && [ "${users_json_ok_result}" == "${users_json_ok}" ]; then
echo -e "${GREEN}test 1/2 success${NC}"
else
    echo -e "${RED}test 1/2 fail${NC}"
fi
echo "___________________________"
echo "${users_json_ok_result}"
echo "___________________________"


users_json_bad_result=$(getJsonFile "${users_file_bad_path}")
if [ $? -eq 0 ]; then
#if [ -z "${users_json_bad}" ]; then #unset or empty string
#if [ -z "${users_json_bad+set}" ]; then #unset
    echo -e "${RED}test 2/2 fail${NC}"
else
    echo -e "${GREEN}test 2/2 success${NC}"
fi
echo "___________________________"
echo "${users_json_bad_result}"
echo -e "___________________________\n\n\n"



echo "___________________________"
echo "____TESTING checkUsers_____"
echo "___________________________"



check_users_ok=$(checkUsers "${users_json_ok}")
if [ $? -eq 0 ]; then
   echo -e "${GREEN}test 1/2 success${NC}"
else
   echo -e "${RED}test 1/2 fail${NC}"
fi
# echo $check_users_ok
echo "___________________________"




check_users_bad=$(checkUsers "${users_json_bad}")
if [ $? -eq 0 ]; then
    echo -e "${RED}test 2/2 fail${NC}"
else
    echo -e "${GREEN}test 2/2 success${NC}"
fi
echo "___________________________"
#echo "${check_users_bad}"
echo -e "___________________________\n\n\n"


echo "___________________________"
echo "____TESTING bashArrayFromInlineJsonArray"
echo "___________________________"


inline_json_array='["item1","item2","item3"]'
# check=$(bashArrayFromInlineJsonArray "${inline_json_array}") # if in subshell, global_bash_array cannot be accessed
bashArrayFromInlineJsonArray "${inline_json_array}"
inline_bash_array=( "${global_bash_array[@]}" ) #global_bash_array is global in docker-entrypoint.sh but not accessible from tests.sh
# expected result : (without the quotes)
# [0] => [item1]
# [1] => [item2]
# [2] => [item3]
echo "___________________________"
#echo "${check}"
for index in "${!inline_bash_array[@]}"; do echo "[${index}] => [${inline_bash_array[$index]}]"; done
echo -e "___________________________\n\n\n"


echo "___________________________"
echo "____TESTING createUsers____"
echo "___________________________"
# TODO TEST CAN ONLY BE PERFORMED IF USERS CORRECTLY PARSED
check_create_users_ok=$(createUsers "${users_json_ok}")
echo "___________________________"
echo "${check_create_users_ok}"
echo -e "___________________________\n\n\n"

# TODO : compare command to be evaled with expected command that should be run.


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



echo "___________________________"
echo "____TESTING setDirOwner____"
echo "___________________________"
# TODO : TEST CAN ONLY BE PERFORMED IF SECTIONS CORRECTLY PARSED AND USERS CORRECTLY CREATED
TEST_DIR=1 #commands cannot be ran on mac
test_dir="test_dir"
test_users="user1 user2 user3"
#test_users="'user1' 'user2' 'Non user3'"
check_set_dir=$(setDirOwner $test_dir $test_users)
echo "___________________________"
echo "${check_set_dir}"
echo -e "___________________________\n\n\n"
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


echo "___________________________"
echo "____TESTING setupShares____"
echo "___________________________"
# TODO : TEST CAN ONLY BE PERFORMED IF SECTIONS CORRECTLY PARSED AND USERS CORRECTLY CREATED (and setDirPerm does not fail)
check_setup_shares=$(setupShares "${sections_json_ok}")
echo "___________________________"
echo "${check_setup_shares}"
echo -e "___________________________\n\n\n"
# TODO : compare command to be evaled with expected command that should be run.


#TODO : test when AFP_USER is set.
#TODO : test when no valid user.
