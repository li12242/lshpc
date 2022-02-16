#!/bin/sh

show_diff(){
    local host=$1
    local diff_str=$2
    nkey=$(echo "$diff_str" | wc -l)
    while [ $nkey -gt 0 ]
    do
        local value=$(echo "$diff_str" | head -n 1 )
        title=$(echo $value | cut -d "|" -f 2 )
        data1=$(echo $value | cut -d "|" -f 3 )
        data2=$(echo $value | cut -d "|" -f 6 )
        printf "%-12s %-12s (Default %-12s)\n" "$title" "$data2" "$data1"
        diff_str=$(echo "$diff_str" | tail -n +2 )
        let nkey--
    done
}

# Main program
db_files=$1
stand_host=$2

cwd=$PWD
if [ -z $db_files ]; then
    db_files=$( ls $cwd/lshpc.db )
fi
# find all tables
table_list=$(sqlite3 $db_files ".tables")

# choose standard table
if [ -z $stand_host ]; then
    stand_host=$(echo $table_list | cut -d " " -f 1)
fi

# compare all tables with stand_host
for host in $table_list
do
    if [ "$host" != "$stand_host" ]; then
        echo "Comparing host "$host" result"
        join_result=$(sqlite3 $db_files "select * from $stand_host inner join $host on ( $stand_host.field = $host.field ) and ( $stand_host.value != $host.value );")
        show_diff $host "$join_result"
    fi
done
