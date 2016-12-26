#!/bin/bash

# DEBUG env var can be set to 1 to enable verbose
# TEST env var can be set to 1 to disable commands
# DIR_TEST env var can be set to 1 to disable dir commands

# getJsonFile {json_file_path} => json array (json_file_path is a string)
# validate a json file and outputs it as a string
getJsonFile ()
{
    json_file_path="${1}"

    error=$(jq -e '.' "${json_file_path}" 2>&1 >/dev/null)
    if [ $? -eq 0 ]; then
        echo "file at path '${json_file_path}' is valid json" >&2
        local json=$(jq '.' "${json_file_path}" -R -s -r -c)
        echo $json
        return 0
    else
        echo "file at path '${json_file_path}' is not valid json" >&2
        echo $error
        return 1
    fi
}

global_bash_array=()

# bashArrayFromMultilineString {multiline_string}
# convert json array into bash array, retrieved via global_bash_array
bashArrayFromMultilineString ()
{
    multiline_string="${1}"

    # split string into array with delimiter \n
    local temp_bash_array=()
    oldIFS="${IFS}"
    IFS=$'\n' read -rd '' -a temp_bash_array <<< "${multiline_string}"
    IFS="${oldIFS}"

    # remove empty lines (needed only when reading with zsh)
    global_bash_array=() #global by default
    for line in "${temp_bash_array[@]}"; do
        # if line not empty add it to returned array
        if [ "${line}" != "" ]; then global_bash_array+=("${line}"); fi
    done

    if [ "${DEBUG}" == "1" ]; then
        echo "check global_bash_array from multiline string :" >&2
        for index in "${!global_bash_array[@]}"; do echo "[${index}] => ${global_bash_array[$index]}" >&2; done
    fi

    # TODO : return success or failure
    #return 0
    #return 1
}

# bashArrayFromInlineJsonArray {json_array} (json_array is an inline json array, ex : ["item1","item2","item3"])
bashArrayFromInlineJsonArray ()
{
    json_array="${1}"

    # trim array brackets
    json_array_stripped=$(echo "${json_array}" | sed 's/^\[\(.*\)\]$/\1/')

    #json_array_stripped=$(echo "${json_array:1: -1}") #does not work in zsh
    local temp_bash_array=()

    # split string into array with delimiter ","
    oldIFS="${IFS}"
    IFS=$',' read -rd '' -a temp_bash_array <<< "${json_array_stripped}"
    IFS="${oldIFS}"

    # remove empty lines (needed only when reading with zsh)
    global_bash_array=() #global by default
    for line in "${temp_bash_array[@]}"; do
        # remove line breaks
        line_cleaned=$(echo "${line}" | tr '\n' ' ')
        #trim leading and trailing space on each line
        line_trimmed=$(echo "${line_cleaned}"  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # remove leading and trailing quotes on each line
        line_no_quotes=$(echo "${line_trimmed}" | sed 's/^"\(.*\)"$/\1/')
        #line_no_quotes="${line%\"}"; line_no_quotes="${line_no_quotes#\"}"
        #line_no_quotes=$(echo "${line}" | sed -e 's/^"//' -e 's/"$//')
        # if line not empty add it to returned array
        if [ "${line_no_quotes}" != "" ]; then global_bash_array+=("${line_no_quotes}"); fi
    done

    if [ "${DEBUG}" == "1" ]; then
        echo "check global_bash_array from inline json array :" >&2
        for index in "${!global_bash_array[@]}"; do echo "[${index}] => ${global_bash_array[$index]}" >&2; done
    fi

    # TODO : return success or failure
    #return 0
    #return 1
}

# getSystemUsernames  => json array
getSystemUsernames ()
{
    usernames=$(cat /etc/passwd | jq 'split ("\n") | map ( split(":") | .[0] ) | map (values) | map (select(. != "")) |  map( tostring | select( . | startswith("#") | not  ) )' -R -s -r -c)
    #TODO : check for failure and exits 1

    echo "${usernames}"

    return 0
}

# parseConfFile {conf_file_path} => json array (conf_file_path is string)
# transform conf file (ini) into json serialized array
parseConfFile ()
{
    conf_file_path="${1}"

    # 0. split by lines, skip empty lines, skip commented lines (begining with ;) - comma sepaarted strings  output (json array)
    conf_json_clean=$(jq '. | split("\n") | map(select(. != "")) | map(select( . | startswith(";") | not  )) ' -R -c -s -r "${conf_file_path}")


    # 1. remove brackets, sort by section or param in type field - line separated output
    conf_json_clean_sorted_trimmed=$(echo "${conf_json_clean}" | jq ' . as $original_array | map( . as $line | { "line" : $line | ltrimstr("[") | rtrimstr("]") , "type" : (if ($line | startswith("[") and endswith("]")) then "section" else "param" end) } ) | .[] ' -r -c)


    # 2. convert it into bash array to add index for each line (jq `walk` not available in jq 1.5)
    bashArrayFromMultilineString "${conf_json_clean_sorted_trimmed}"
    conf_clean_sorted_trimmed_array=( "${global_bash_array[@]}" )
    if [ "${DEBUG}" == "1" ]; then
    echo "check conf_clean_sorted_trimmed_array :" >&2
        for line in "${conf_clean_sorted_trimmed_array[@]}"; do echo "${line}" >&2; done
    fi


    # 3. add parent section to each param line
    conf_clean_sorted_trimmed_parent_array=()
    for index in "${!conf_clean_sorted_trimmed_array[@]}"; do
        item=${conf_clean_sorted_trimmed_array[$index]}
        #echo "item : ${item}"

        item_type=$(echo "${item}" | jq ' .type ' -r -c)
        #echo "item_type : ${item_type}"

        if [ "${item_type}" == "param" ]; then
            previous_index=$index
            previous_item=${conf_clean_sorted_trimmed_array[$previous_index]}
            #echo "previous_item : ${previous_item}"
            previous_item_type=$(echo $previous_item | jq ' .type ' -r -c)
            #echo "previous_item_type : ${previous_item_type}"
            while [ "${previous_item_type}" != "section" ]; do
                #previous_index-=1
                previous_index=$(($previous_index-1))
                #echo "previous_index : ${previous_index}"
                previous_item=${conf_clean_sorted_trimmed_array[$previous_index]}
                #echo $previous_item
                #echo "previous_item : ${previous_item}"
                previous_item_type=$(echo "${previous_item}" | jq ' .type ' -r -c)
                #echo "previous_item_type : ${previous_item_type}"
            done
            parent_item_line=$(echo "${previous_item}" | jq ' .line ' -r -c)
            param=$(echo "${item}" | eval "jq ' { \"line\" : .line,  \"type\" : .type, \"section\" : \"${parent_item_line}\" } ' -r -c")
            conf_clean_sorted_trimmed_parent_array+=("${param}")
        else
            #echo "adding section : ${item}"
            conf_clean_sorted_trimmed_parent_array+=("${item}")
        fi
    done

    if [ "${DEBUG}" == "1" ]; then
    echo "array with params having sections property : " >&2
        for line in "${conf_clean_sorted_trimmed_parent_array[@]}"; do echo "${line}" >&2; done
    fi

    # get json from bash array
    conf_clean_sorted_trimmed_parent_json=$(printf "%s\n" "${conf_clean_sorted_trimmed_parent_array[@]}" | jq '. | split("\n") | map(select(. != "")) | map (. | fromjson | .) ' -R -c -s )
    if [ "${DEBUG}" == "1" ]; then echo "${conf_clean_sorted_trimmed_parent_json}" >&2; fi


    # 4. create json with sections as keys and params as values

    # 4.1 organize param lines into json objects representing sections
    conf_clean_sorted_trimmed_parent_paramlines_json=$(echo "${conf_clean_sorted_trimmed_parent_json}" | jq '. as $original_array | map ( if .type == "section" then .line as $section | $original_array | map(select(.type == "param" and .section == $section) | .line) | . as $param_line | { "name" : $section, "params" : $param_line } else empty end )' -r -c)
    if [ "${DEBUG}" == "1" ]; then echo "${conf_clean_sorted_trimmed_parent_paramlines_json}" >&2; fi

    # 4.2 parse param lines as json objects
    conf_json_final=$(echo "${conf_clean_sorted_trimmed_parent_paramlines_json}" | jq ' map ( . as $section | .params | map (split(" = ") | .[0] as $param_key | .[1] as $param_value | { ($param_key) : $param_value } ) | . | add | . as $params | [{ "name": $section.name }, $params ] | add ) ' -r -c)

    echo "${conf_json_final}"

    return 0
}


#checkSections {sections_json} {usernames} => message (sections_json are json objects and usernames is json array)
#verify that 1. share sections users exist 2. share sections have path property 3. not 2 identical sections
checkSections ()
{
    sections_json="${1}"
    usernames="${2}"

    # 1. check if all users defined in sections belong to usernames array
    sections_users=$(echo "${sections_json}" | jq 'map(."valid users") | map( if . == null then empty else split(" ") end ) | map(.[])' -r -c)

    sections_users_check=$(echo "${usernames}" | jq "contains(${sections_users})" -r -c)
    if [ "${sections_users_check}" == "true" ]; then
        echo "all users defined in sections exist in system"
    else
        echo "some users defined in sections (valid users) do not exist in system"
        echo "sections users : ${sections_users}"
        echo "system usernames : ${usernames}"
        # TODO : specify which section is invalid
        return 1
    fi


    # 2. check if all sections have a path property
    sections_path_check=$(echo "${sections_json}" | jq 'map(.path) | indices(null) | .[0]' -r -c)
    #if [ -z "${sections_path_check}" ]; then #if sections_path_check unset or empty string
    if [ "${sections_path_check}" == "null" ]; then
        #ok, none of the sections have null path
        echo "all sections have path"
    else
        #bad
        echo "one or more sections are invalid"
        # TODO : echo paths
        # TODO : specify which section is invalid
        return 1

    fi

    # 3. check if all sections have unique names
    sections_names_check=$(echo "${sections_json}" | jq 'group_by(.name) | map (length) | contains([2]) ' -r -c)
    if [ "${sections_names_check}" == "true" ]; then
        echo "some sections have identical names"
        # TODO : specify which sections have same name
        return 1
    else
        echo "all sections have unique name"
    fi

    return 0
}


# checkUsers {users_json} => message (users_json are json objects)
# verify that 1. users have a username 2. not 2 identical users
checkUsers ()
{
    users_json="${1}"

    # 1. check if all users have a username property (select username of each user, if one item of the returned array is empty ==> failure)
    users_username_check=$(echo "${users_json}" | jq 'map(.username) | indices(null) | .[0]' -r -c)
    #if [ -z "${users_username_check}" ]; then #if users_username_check unset or empty string
    if [ "${users_username_check}" == "null" ]; then
        #ok, none of the users have null username
        echo "all users have username"
    else
        #bad
        echo "one or more users are invalid"
        # TODO : specify which user is invalid
        return 1
    fi

    # 2. check if all users have unique usernames
    users_usernames_check=$(echo "${users_json}" | jq 'group_by(.username) | map (length) | contains([2]) ' -r -c)
    if [ "${users_usernames_check}" == "true" ]; then
        echo "some users have identical usernames"
        # TODO : specify which users have same name
        return 1
    else
        echo "all users have unique username"
    fi

    return 0
}





# setDirOwner {directory_path} {usernames} (directory_path is string and usernames is a json array)
# set directory ownership for a single user or a group of users
setDirOwner ()
{
    dir_path="${1}"
    dir_name=$(basename "${dir_path}")

    if [ "${DEBUG}" == "1" ]; then echo "setting permissions for dir '${dir_name}' at path '${dir_path}'"; fi

    # create directory if it does not already exist
    if [ ! -d "${dir_path}" ]; then
        mkdir_command="mkdir ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "mkdir_command : '${mkdir_command}'"; fi
        if [ "${TEST_DIR}" != "1" ]; then eval $mkdir_command; fi
        echo "use -v /my/dir/to/share:${dir_path}" > readme.txt
    fi

    # grab users provided as json array
    bashArrayFromInlineJsonArray "${2}"
    local dir_usernames_array=( "${global_bash_array[@]}" )

    # no user provided - make dir RW to every user (by default guest access when no valid users property)
    # TODO : read setting about guest access in Global section
    if [ -z ${dir_usernames_array} ]; then

        chmod_command="chmod +rwx ${dir_path}"
        if [ "${DEBUG}" == "1" ]; then echo "no user for dir '${dir_name}' : guest access, chmod_command : '${chmod_command}'"; fi
        if [ "${TEST_DIR}" != "1" ]; then eval $chmod_command; fi
    else

        # if only one user, chown to this user
        if [ ${#dir_usernames_array[@]} == 1 ]; then

            chown_command="chown ${dir_usernames_array[0]} ${dir_path}"
            if [ "${DEBUG}" == "1" ]; then echo "one user '${dir_usernames_array[0]}' for dir '${dir_name}', chown_command : '${chown_command}'"; fi
            if [ "${TEST_DIR}" != "1" ]; then eval $chown_command; fi

        # if more than one user, create a group, add users to this group and set this group as dir owner
        else

            if [ "${DEBUG}" == "1" ]; then
                echo "users for dir '${dir_name}' are :"
                for username in "${dir_usernames_array[@]}"; do echo "'${username}'"; done
            fi

            #TODO : check if group name does not already exists (different directories can have same basename)
            group_name="${dir_name}_group"
            if [ "${DEBUG}" == "1" ]; then echo "group_name : '${group_name}'"; fi

            create_group_command="groupadd ${group_name}"
            if [ "${DEBUG}" == "1" ]; then echo "create_group_command : '${create_group_command}'"; fi
            if [ "${TEST_DIR}" != "1" ]; then eval $create_group_command; fi

            for username in "${dir_usernames_array[@]}"; do
                pass_command="gpasswd -a ${username} ${group_name}"
                if [ "${DEBUG}" == "1" ]; then echo "pass_command : '${pass_command}'"; fi
                if [ "${TEST_DIR}" != "1" ]; then eval $pass_command; fi
            done

            chown_command="chown -R ${dir_usernames_array[0]}:${group_name} ${dir_path}"
            if [ "${DEBUG}" == "1" ]; then echo "chown_command : '${chown_command}'"; fi
            if [ "${TEST_DIR}" != "1" ]; then eval $chown_command; fi

            chmod_command="chmod -R g+w ${dir_path}"
            if [ "${DEBUG}" == "1" ]; then echo "chmod_command : '${chmod_command}'"; fi
            if [ "${TEST_DIR}" != "1" ]; then eval $chmod_command; fi
        fi
    fi

    return 0
}

#setupShares {sections_json} {?default_user} (sections_json are json objects and default_user is optional string)
# create dir with correct ownership for each share
setupShares ()
{
    sections_json="${1}"
    default_user="${2}" #optional

    # loop through each share
    sections_json_array=$(echo "${sections_json}" | jq 'map(.name)' -r -c)
    bashArrayFromInlineJsonArray "${sections_json_array}"
    local ordinary_sections=( "${global_bash_array[@]}" )
    for section_name in "${ordinary_sections[@]}"; do

        #get path paramater value for this section
        section_path=$(echo "${sections_json}" | jq "map(select(.name == \"${section_name}\" )) | .[0].path" -r -c)

        # get valid users parameter value for this section as json array, ex ["user1", "user2", "user3"] (return empty if no property valid users)
        section_valid_users=$(echo "${sections_json}" | jq "map(select(.name == \"${section_name}\" )) | .[0].\"valid users\" | if . == null then empty else split(\" \") end " -r -c)
        if [ "${DEBUG}" == "1" ]; then echo "valid users for share ${section_name} are '${section_valid_users}'"; fi

        # use env vars if no valid users provided in conf file
        if [ -z "${section_valid_users}" ]; then

            if [ ! -z "${default_user}" ]; then
                if [ "${DEBUG}" == "1" ]; then echo "no valid users provided for share ${section_name}, share user defaulting to default user"; fi
                section_valid_users="${default_user}"
            else
                if [ "${DEBUG}" == "1" ]; then echo "no valid users provided for share ${section_name} and no default user provided"; fi
            fi
        fi

        # apply permissions/ownership for this directory
        setDirOwner "${section_path}" "${section_valid_users}"
    done

    return 0
}



# createUsers {users_json} (users_json are json objects)
# creates unix users and groups defined in users json file
createUsers ()
{
    users_json="${1}"

    # array which holds groups already created
    local afp_guids=()

    usernames_json_array=$(echo "${users_json}" | jq 'map(.username)' -r -c)
    bashArrayFromInlineJsonArray "${usernames_json_array}"
    local usernames=( "${global_bash_array[@]}" )
    for username in "${usernames[@]}"; do

        # get values for parameters from array
        afp_uid=$(echo "${users_json}" | jq "map(select(.username == \"${username}\" )) | .[0].uid // empty" -r -c)
        afp_gid=$(echo "${users_json}" | jq "map(select(.username == \"${username}\" )) | .[0].gid // empty" -r -c)
        afp_password=$(echo "${users_json}" | jq "map(select(.username == \"${username}\" )) | .[0].password // empty" -r -c)

        if [ "${DEBUG}" == "1" ]; then echo "create user ${username}"; fi

        # command string to add user  (needs to be reset at the begining of each loop, otherwise keeps being appended throughout the loops)
        create_user_command=""

        # if provided, add uid argument
        if [ ! -z "${afp_uid}" ]; then
        #if [[ ! -z "${afp_uid}" && "${afp_uid}" != "null" ]]; then
            if [ "${DEBUG}" == "1" ]; then echo "afp_uid ${afp_uid} correctly set"; fi
            create_user_command="${create_user_command} --uid ${afp_uid}"
            #create_user_command+=" --uid ${afp_uid}"
            if [ "${DEBUG}" == "1" ]; then echo "create_user_command is now ${create_user_command}"; fi
        fi

        # if provided, add gid argument
        if [ ! -z "${afp_gid}" ];  then
            if [ "${DEBUG}" == "1" ]; then echo "afp_gid ${afp_uid} correctly set"; fi
            #create_user_command="${create_user_command} --gid ${afp_gid}"
            create_user_command+=" --gid ${afp_gid}"
            if [ "${DEBUG}" == "1" ]; then echo "create_user_command is now ${create_user_command}"; fi

            #if necessary, create group
            if [[ "${afp_guids[@]}" =~ "${afp_gid}" ]]; then
                if [ "${DEBUG}" == "1" ]; then echo "group for gid ${afp_gid} already created"; fi
            else
                if [ "${DEBUG}" == "1" ]; then echo "no existing group for gid ${afp_gid}"
                afp_guids+=("${afp_gid}"); fi
                create_group_command="groupadd --gid ${afp_gid} ${username}"
                if [ "${DEBUG}" == "1" ]; then echo "command to create group for user ${username} : '${create_group_command}'"; fi

                # execute command
                if [ "${TEST}" != "1" ]; then eval $create_group_command; fi

            fi
        fi

        # create user with all provided arguments
        create_user_command="adduser${create_user_command} --no-create-home --disabled-password --gecos '' ${username}"
        if [ "${DEBUG}" == "1" ]; then echo "command to create user ${afp_username} : '${create_user_command}'"; fi

        # execute command
        if [ "${TEST}" != "1" ]; then eval $create_user_command; fi


        # if provided, modify password
        if [ ! -z "${afp_password}" ]; then
            if [ "${DEBUG}" == "1" ]; then echo "afp_password correctly set"; fi
            change_password_command="echo \"${username}:${afp_password}\" | chpasswd"
            if [ "${DEBUG}" == "1" ]; then echo "command to change password : '${change_password_command}'"; fi

            # execute command
            if [ "${TEST}" != "1" ]; then eval $change_password_command; fi
        fi

        if [ "${DEBUG}" == "1" ]; then echo ""; fi

    done

    return 0
}



# users configuration - json file can be provided or AFP_USER env var can be set
users_file_path="${1}"
#users_file_path="/etc/users.json"
#users_file_path="/Volumes/data/dri/projets/docker-netatalk/test-files/users-test-ok.json"

if [ -f ${users_file_path} ]; then
   echo "users file found at path ${users_file_path}."

   users_json=$(getJsonFile "${users_file_path}")
   if [ $? -eq 0 ]; then

       users_check=$(checkUsers "${users_json}")
       if [ $? -eq 0 ]; then
           createUsers "${users_json}"
       else
           echo "${users_check}"
       fi
   else
       echo "${users_json}"
   fi

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
conf_file_path="${2}"
#conf_file_path="/etc/afp.conf"
#conf_file_path="/Volumes/data/dri/projets/docker-netatalk/test-files/afp-test-mba.conf"
if [ -f ${conf_file_path} ]; then
    echo "conf file found at ${conf_file_path}."

    # look for "%USER%" string in conf file uncommented lines (exit 1 if no results)
    check_default_conf=$(grep "^[^#;]" "${conf_file_path}" | grep -q "%USER%")
    if [ $? -ne 0 ]; then

        echo "using multi users conf file."

        # parse conf file to json organized data
        conf_json=$(parseConfFile "${conf_file_path}")

        echo "conf json is : ${conf_json}"
        #filter conf_json using jq select to keep only shares and time machine sections
        sections_json=$(echo "${conf_json}" | jq 'map(select(.name != "Global" and .name != "Homes" ))' -r -c)

        # get existing usernames from /etc/passwd
        usernames=$(getSystemUsernames)

        # check if sections are valid
        sections_check=$(checkSections "${sections_json}" "${usernames}")
        if [ $? -eq 0 ]; then
            # create dir with correct permissions for each section
            setupShares "${sections_json}" "${AFP_USER}"
        else
            echo "${sections_check}";
        fi
    else
        # alternatively, if using single user afp.conf, use (if provided) env vars AFP_USER, AFP_UID, AFP_GID and AFP_PASSWORD (single user configuration)
        echo "using single user conf file."
        if [ ! -z "${AFP_USER}" ]; then
            # if AFP_USER declared replace %USER% with env var value AFP_USER
          sed -i'' -e "s,%USER%,${AFP_USER:-},g" ${conf_file_path}
        else
          #TODO : stop program. netatalk won't run if valid users property is wrong
          if [ "${DEBUG}" == "1" ]; then echo "env var AFP_USER not set"; fi
        fi

        #TODO : add missing code from original docker-entrypoint.sh, espacially time machine shit
    fi

    # read afp.conf
    echo ---begin-afp.conf--
    cat ${conf_file_path}
    echo ---end---afp.conf--
else
   echo "conf file not found at ${conf_file_path}."
fi

# other
if [ "${TEST}" != "1" ]; then

    # restart d-bus daemon
    mkdir -p /var/run/dbus
    rm -f /var/run/dbus/pid
    dbus-daemon --system

    # start avahi (if env var set)
    if [ "${AVAHI}" == "1" ]; then
        sed -i '/rlimit-nproc/d' /etc/avahi/avahi-daemon.conf
        avahi-daemon -D
    else
        echo "Skipping avahi daemon, enable with env variable AVAHI=1"
    fi;

    # start netatalk
    exec netatalk -d
fi
