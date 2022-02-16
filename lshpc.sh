#!/bin/sh

split_blank(){
    input=$1
    echo $( echo $input | sed 's/^[ \t]*//g' | sed 's/[ \t]*$//g' )
}

# Read specific string value, seperated by '|' or other str
# Usage:
#   read_key '"CPU Freq" | dmidecode -t processor' 2
#   read_key '"CPU Freq" | dmidecode -t processor' 2 "|"
read_key(){
    local str=$1
    local num=$2
    local sep='|'
    if [ -z $3 ]; then
        sep='|'
    else
        sep=$3
    fi
    local data=$(echo $str | cut -d $sep -f $num)
    # echo $(split_blank $data)
    echo $(eval echo $data)
}

# Read and eval command string
# The string 
read_cmd(){
    local cmd_str=$1
    local header=$(read_key $cmd_str 1)
    # return header
    echo $header
    local nkey=$(echo $cmd_str | grep -o "|" | wc -l ) 
    local cmd=$(read_key $cmd_str 2)
    local value=$(eval $cmd)
    local counter=1
    while [ $counter -le $nkey ]
    do
        local post_cmd=$(read_key $cmd_str $[ $counter + 1 ])
        value=$(echo "$value" | eval $post_cmd)
        let counter++
    done
    echo "$value"
}

create_table(){
    DATA_BASE=lshpc.db
    is_exit=`sqlite3 ${DATA_BASE} "select count(*) from sqlite_master where type='table' and name='"$HOSTNAME"';"`
    if [ $is_exit -eq 1 ]; then
        echo "Deleting existing table "${HOSTNAME}
        sqlite3 ${DATA_BASE} "DROP TABLE "$HOSTNAME
    fi
    echo "Generating table "$HOSTNAME
    sqlite3 ${DATA_BASE} "create table \"$HOSTNAME\" (id INTEGER PRIMARY KEY,FIELD CHAR(50),VALUE CHAR(50));"
}


insert_table(){
    string=$1
    # echo "$string"
    local title=$(echo "$string" | head -n 1)
    local data=$(echo "$string" | tail -n +2)
    local nkey=$[ $(echo "$data" | wc -l) ]
    # echo "nkey = "$nkey
    # echo "title = "$title
    # echo "data = $data"
    if [ $nkey -gt 1 ]; then
        local counter=0 # title num
        while [ $nkey -gt 0 ]
        do
            local value=$(echo "$data" | head -n 1)
            value=$(split_blank $(echo $value | cut -d ":" -f 2))
            data=$(echo "$data" | tail -n +2)
            # echo "Field = $title$counter, Value = $value"
            sqlite3 ${DATA_BASE} "insert into \"$HOSTNAME\" (FIELD,VALUE) values (\"$title$counter\",\"$value\");"
            let nkey--
            let counter++
        done
    else
        local value=$(split_blank $(echo $data | cut -d ":" -f 2))
        # echo "Field = $title, Value = $value"
        sqlite3 ${DATA_BASE} "insert into \"$HOSTNAME\" (FIELD,VALUE) values (\"$title\",\"$value\");"
    fi 
}

# main program
config=$1

# check config file
if [ -z $config ]; then
    config="cmd.conf"
fi

# redefine sep and read config file once a line
OLDIFS=$IFS
IFS=$'\n'

# generate database
create_table
counter=1
for cmd in $(cat $config)
do
    echo "Processing CMD " $counter ": $cmd"
    # eval cmd and get data
    data=$(read_cmd $cmd)
    echo "Reading Data: $data"
    # insert into database
    insert_table "$data"
    let counter++
done
IFS=$OLDIFS
