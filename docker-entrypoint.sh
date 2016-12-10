#!/bin/bash

# DEBUG env var can be set to enable verbose
# TEST env var can be set to disable commands


# PARSE FUNCTIONS

# parseConf {conf_file_path}
# load sections of a conf file into `sections` array
# load params and values into associative array `section_params[section.param]=value`
parseConf ()
{
    conf_file_path="${1}"
    sections=()
    declare -A -g section_params=()

    # source shini
    current_dir="$(cd "$(dirname "$0")"; pwd)"
    if [ "${DEBUG}" == "1" ]; then echo "current directory is ${current_dir}"; fi
    path_to_shini="${current_dir}/shini/shini.sh"
    # can result in two leading slashes  if current dir is root dir but no PB
    if [ "${DEBUG}" == "1" ]; then echo "shini script path is '${path_to_shini}'"; fi
    source "${path_to_shini}"

    __shini_parsed ()
    {
        if [[ " ${sections[@]} " =~ " ${1} " ]]; then
            if [ "${DEBUG}" == "1" ]; then echo "section [${1}] already exists"; fi
        else
            if [ "${DEBUG}" == "1" ]; then echo "new section [${1}]"; fi
            sections+=("${1}")
        fi

        # store params into associative array
        # section_params[section.param]=value
        section_params["${1}.${2}"]="${3}"

        if [ "${DEBUG}" == "1" ]; then echo "section [${1}], key : {${2}} => value : '${3}'"; fi
        if [ "${DEBUG}" == "1" ]; then echo ""; fi
    }

    # trigger parsing
    shini_parse ${conf_file_path}
}



# parseUsers {conf_file_path}
# load users of a users file into `users` array
# load params and values into associative array `user_params[user.param]=value`
parseUsers ()
{
    user_file_path="${1}"
    users=()
    declare -A -g user_params=()

    # array of numbers from 0 to number of users
    array_of_indexes=$(jq -r '.afp_users|keys[]' ${user_file_path})

    # loop through all users
    for i in ${array_of_indexes[@]}; do

        afp_username=$(jq -r ".afp_users[$i].username // empty" ${user_file_path})
        afp_password=$(jq -r ".afp_users[$i].password // empty" ${user_file_path})
        afp_uid=$(jq -r ".afp_users[$i].uid // empty" ${user_file_path})
        afp_gid=$(jq -r ".afp_users[$i].gid // empty" ${user_file_path})

        if [ "${DEBUG}" == "1" ]; then echo "__________________________"; fi
        if [ "${DEBUG}" == "1" ]; then echo "${afp_username}"; fi
        if [ "${DEBUG}" == "1" ]; then echo "${afp_password}"; fi
        if [ "${DEBUG}" == "1" ]; then echo "${afp_uid}"; fi
        if [ "${DEBUG}" == "1" ]; then echo "${afp_gid}"; fi

        # check if param username is set
        if [ ! -z "${afp_username}" ]; then

            if [ "${DEBUG}" == "1" ]; then echo "username ${afp_username} correctly set"; fi

            # check if user already exists
            if [[ " ${users[@]} " =~ " ${afp_username} " ]]; then
                # already exists
                if [ "${DEBUG}" == "1" ]; then echo "user ${afp_username} already exists"; fi
                #TODO : check if there are no new params
                #printf 'already exists, users array now %s\n' "${users[@]}"

            else
                # new user : store it into users array
                if [ "${DEBUG}" == "1" ]; then echo "new user ${afp_username}"; fi
                users+=("${afp_username}")
                #printf 'users array now %s\n' "${users[@]}"

                # store parameters and corresponding values into user_params array  (user_params[user.param]=value)
                if [ ! -z "${afp_uid}" ]; then
                    user_params["${afp_username}.uid"]="${afp_uid}"
                fi

                if [ ! -z "${afp_gid}" ]; then
                    user_params["${afp_username}.gid"]="${afp_gid}"
                fi

                if [ ! -z "${afp_password}" ]; then
                    user_params["${afp_username}.password"]="${afp_password}"
                fi
            fi
        fi

    done

    if [ "${DEBUG}" == "1" ]; then echo ""; fi
}




# HELPER FUNCTIONS

# getValue {prefix} {thing} {param_name} : get value of param (for a section)
getValue ()
{
    # get args
    prefix="${1}" #ex : "section" or "user"
    thing="${2}" # desired section or user, ex "user1" or "Share2"
    param_name="${3}" # desired param, ex "valid users" or "gid"

    local local_value=()

    key="${thing}.${param_name}"
    array_name="${prefix}_params"
    local_value=$(eval "echo \${${array_name}[\"$key\"]}")

    # debug echos only on screen
    if [ "${DEBUG}" == "1" ]; then echo "getting key {${key}} with value '${local_value}'" >&2; fi

    # return value
    echo "${local_value}"
}




# getAllSectionsBut {sections_to_exclude} : returns all sections except the ones passed in args
getAllSectionsBut ()
{
    filtered_sections=()

    # go through all arguments (unknown number)
    local excludedSections=()
    while [ -n "${1}" ]; do
        #if [ "${DEBUG}" == "1" ]; echo "section [$1] filtered, remaining $# sections"; fi
        if [ "${DEBUG}" == "1" ]; then echo "excluding section [${1}]"; fi
        excludedSections+=("${1}")
        shift
    done


    for section in "${sections[@]}"; do
        #if [[ "${section}" == "${excludedSection}" ]]; then
        if [[ " ${excludedSections[@]} " =~ " ${section} " ]]; then
            if [ "${DEBUG}" == "1" ]; then echo "${section} is an excluded section"; fi
        else
            filtered_sections+=("${section}")
        fi
    done
}

# getOrdinarySections : filter sections to keep only oridnary sections (special sections are [Global] and [Homes])
getOrdinarySections ()
{
    getAllSectionsBut "Global" "Homes"
}


# SETUP FUNCTIONS

# setDirOwner {directory_path} {users} - users is space separated list
# set directory ownership for a single user or a group of users
setDirOwner ()
{
    dir_path="${1}"
    dir_name=$(basename "${dir_path}")

    #if [ "${DEBUG}" == "1" ]; then echo "setting permissions for dir at path '${dir_path}' for users '${dir_users}'"; fi
    if [ "${DEBUG}" == "1" ]; then echo "setting permissions for dir '${dir_name}' at path '${dir_path}'"; fi

    # create directory if it does not already exist
    if [ ! -d "${dir_path}" ]; then
        mkdir_command="mkdir ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "mkdir_command is '${mkdir_command}'"; fi
        if [ "${DIR_TEST}" != "1" ]; then eval $mkdir_command; fi
        echo "use -v /my/dir/to/share:${dir_path}" > readme.txt
    fi


    # grab users provided (unknown number)
    local dir_users_array=()
    shift
    for argument in "$@"; do
    #for argument in "${$[@]:1}"; do
        dir_users_array+=("${argument}")
    done
    echo "users for dir '${dir_name}' are :"
    for user in "${dir_users_array[@]}"; do echo "${user}"; done

    # if only one user, chown to this user
    if [ ${#dir_users_array[@]} == 1 ]; then
        chown_command="chown ${dir_users_array[0]} ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "only one user for ${dir_name}, chown_command is '${chown_command}'"; fi
        if [ "${DIR_TEST}" != "1" ]; then eval $chown_command; fi


    # if more than one user,
    # create a group and add users to this group,
    # and finally set owner to group which users belong
    # source : http://superuser.com/a/695186
    else
        #TODO : check if group name does not already exists (different folders can have same basename)
        group_name="${dir_name}_group"
        if [ "${DEBUG}" == "1" ]; then printf "group_name is ${group_name}"; fi

        create_group_command="groupadd ${group_name}"
        if [ "${DEBUG}" == "1" ]; then echo "create_group_command is '${create_group_command}'"; fi
        if [ "${DIR_TEST}" != "1" ]; then eval $create_group_command; fi

        for dir_user in "${dir_users_array[@]}"; do
            pass_command="gpasswd -a ${dir_user} ${group_name}"
            if [ "${DEBUG}" == "1" ]; then echo "pass_command is '${pass_command}'"; fi
            if [ "${DIR_TEST}" != "1" ]; then eval $pass_command; fi
        done

        chown_command="chown -R ${dir_users_array[0]}:${group_name} ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "chown_command is '${chown_command}'"; fi
        if [ "${DIR_TEST}" != "1" ]; then eval $chown_command; fi

        chmod_command="chmod -R g+w ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "chmod_command is '${chmod_command}'"; fi
        if [ "${DIR_TEST}" != "1" ]; then eval $chmod_command; fi
    fi
}

#setupVolumes {?default_user}
#TODO : pass sections and their paramaters to the function instead of using global array
setupVolumes ()
{
    default_user="${1}"
    getOrdinarySections #shortcut for getAllSectionsBut "Global" "Homes"
    ordinary_sections=( "${filtered_sections[@]}" )

    # loop through each share
    for section_name in "${ordinary_sections[@]}"; do

        #get values for parameters from array
        section_path=$(getValue "section" "${section_name}" "path")
        section_valid_users=$(getValue "section" "${section_name}" "valid users") # space separated array

        echo "valid users for share ${section_name} are '${section_valid_users}'"

        # use env vars if no valid users provided in conf file
        if [ -z "${section_valid_users}" ]; then
            echo "no valid users '${section_valid_users}' provided for share ${section_name}"

            if [ ! -z "${default_user}" ]; then
                if [ "${DEBUG}" == "1" ]; then echo "no valid users provided for share ${section_name}, share user defaulting to default user"; fi
                section_valid_users="${default_user}"
            else
                #TODO : make it guest.
                if [ "${DEBUG}" == "1" ]; then echo "no valid users provided for share ${section_name} and no default user provided"; fi
            fi
        fi

        # apply permissions/ownership
        setDirOwner $section_path $section_valid_users
    done
}



# createUsers {?users_array}
#TODO : pass users and their parameters to the function instead of using global array
createUsers ()
{
    # users="${1}"

    # array which holds groups already created
    local afp_guids=()

    for afp_username in "${users[@]}"; do

        #get values for parameters from array
        afp_uid=$(getValue "user" ${afp_username} "uid")
        afp_gid=$(getValue "user" ${afp_username} "gid")
        afp_password=$(getValue "user" ${afp_username} "password")

        if [ "${DEBUG}" == "1" ]; then echo "create user ${afp_username}"; fi

        # command string to add user  (needs to be reset at the begining of each loop, otherwise keeps being appended throughout the loops)
        create_user_command=""

        # if provided, add uid argument
        if [ ! -z "${afp_uid}" ]; then
        #if [[ ! -z "${afp_uid}" && "${afp_uid}" != "null" ]]; then
            if [ "${DEBUG}" == "1" ]; then echo "afp_uid ${afp_uid} correctly set"; fi
            create_user_command="${create_user_command} --uid ${afp_uid}"
            if [ "${DEBUG}" == "1" ]; then echo "create_user_command is now ${create_user_command}"; fi
        fi

        # if provided, add gid argument
        if [ ! -z "${afp_gid}" ];  then
            if [ "${DEBUG}" == "1" ]; then echo "afp_gid ${afp_uid} correctly set"; fi
            create_user_command="${create_user_command} --gid ${afp_gid}"
            if [ "${DEBUG}" == "1" ]; then echo "create_user_command is now ${create_user_command}"; fi

            #if necessary, create group
            if [[ "${afp_guids[@]}" =~ "${afp_gid}" ]]; then
                if [ "${DEBUG}" == "1" ]; then echo "group for gid ${afp_gid} already created"; fi
            else
                if [ "${DEBUG}" == "1" ]; then echo "no existing group for gid ${afp_gid}"
                afp_guids+=("${afp_gid}"); fi
                create_group_command="groupadd --gid ${afp_gid} ${afp_username}"
                if [ "${DEBUG}" == "1" ]; then echo "command to create group for user ${afp_username} is '${create_group_command}'"; fi

                # execute command
                if [ "${TEST}" != "1" ]; then eval $create_group_command; fi

            fi
        fi

        # create user with all provided arguments
        create_user_command="adduser${create_user_command} --no-create-home --disabled-password --gecos '' ${afp_username}"
        if [ "${DEBUG}" == "1" ]; then echo "command to create user ${afp_username} is '${create_user_command}'"; fi

        # execute command
        if [ "${TEST}" != "1" ]; then eval $create_user_command; fi


        # if provided, modify password
        if [ ! -z "${afp_password}" ]; then
            if [ "${DEBUG}" == "1" ]; then echo "afp_password correctly set"; fi
            change_password_command="echo \"${afp_username}:${afp_password}\" | chpasswd"
            if [ "${DEBUG}" == "1" ]; then echo "command to change password is '${change_password_command}'"; fi

            # execute command
            if [ "${TEST}" != "1" ]; then eval $change_password_command; fi
        fi

        if [ "${DEBUG}" == "1" ]; then echo ""; fi

    done
}


# MAIN

# users conf - json file can be provided.
users_file_path="/etc/users.json"
if [ -f ${users_file_path} ]; then
   echo "users file found at path ${users_file_path}."
   parseUsers "${users_file_path}"
   createUsers
else
   echo "users file not found at path ${users_file_path}."
   # alternatively, if no users.json file provided, use (if provided) env vars AFP_USER, AFP_UID, AFP_GID and AFP_PASSWORD (single user configuration)
if [ ! -z "${AFP_USER}" ]; then
    if [ ! -z "${AFP_UID}" ]; then
        cmd="$cmd --uid ${AFP_UID}"
    fi
    if [ ! -z "${AFP_GID}" ]; then
        cmd="$cmd --gid ${AFP_GID}"
        groupadd --gid ${AFP_GID} ${AFP_USER}
    fi
    adduser $cmd --no-create-home --disabled-password --gecos '' "${AFP_USER}"
    if [ ! -z "${AFP_PASSWORD}" ]; then
        echo "${AFP_USER}:${AFP_PASSWORD}" | chpasswd
    fi
fi
fi

# netatalk conf - default afp.conf can be overridden with custom afp.conf.
conf_file_path="/etc/afp.conf"
if [ -f ${conf_file_path} ]; then
    echo "conf file found at ${conf_file_path}."

    #if [[ $(grep -q "%USER%" ${conf_file_path}) -ne 0 ]]; then
        echo "using custom conf file."
        # share directories : for each share defined in afp.conf (including a time machine session), create and set dir owner
        parseConf "${conf_file_path}"
        setupVolumes "${AFP_USER}"
    # else
    #     # alternatively, if using default afp.conf, use (if provided) env vars AFP_USER, AFP_UID, AFP_GID and AFP_PASSWORD (single user configuration)
    #     echo "using default conf file."
    #     if [ ! -z "${AFP_USER}" ]; then
    #         # if AFP_USER declared replace %USER% with env var value AFP_USER
    #       sed -i'' -e "s,%USER%,${AFP_USER:-},g" ${conf_file_path}
    #     else
    #       #TODO : stop program. netatalk won't run if valid users property is wrong
    #       if [ "${DEBUG}" == "1" ]; then echo "env var AFP_USER not set"; fi
    #     fi
    #
    #     #TODO : add missing code from original docker-entrypoint.sh, espacially time machine shit
    # fi

    # read afp.conf
    echo ---begin-afp.conf--
    cat ${conf_file_path}
    echo ---end---afp.conf--
else
   echo "conf file not found at ${conf_file_path}."
fi

if [ "${TEST}" != "1" ]; then

    # ?
    mkdir -p /var/run/dbus
    rm -f /var/run/dbus/pid
    dbus-daemon --system

    # run avahi
    if [ "${AVAHI}" == "1" ]; then
        sed -i '/rlimit-nproc/d' /etc/avahi/avahi-daemon.conf
        avahi-daemon -D
    else
        echo "Skipping avahi daemon, enable with env variable AVAHI=1"
    fi;

    # run netatalk
    exec netatalk -d
fi
