#!/bin/sh

help="\
hw2.sh -p TASK_ID -t TASK_TYPE [-h]

Available Options:

-p: Task id
-t JOIN_NYCU_CSIT|MATH_SOLVER|CRACK_PASSWORD: Task type
-h: Show the script usage"

solve_math() {
    problem="$1"
    
    # Remove the trailing "= ?" from the problem
    problem=$(echo "$problem" | sed 's/ = ?//')

    # Use regex to check for valid math problem format: a (+/-) b
    if echo "$problem" | grep -Eq '^(-?[0-9]+) (\+|\-) ([0-9]+)$'; then
        # Extract values a, operator, and b
        a=$(echo "$problem" | sed 's/\([0-9\-]*\) .*/\1/')
        op=$(echo "$problem" | sed 's/[0-9\-]* \([+-]\) .*/\1/')
        b=$(echo "$problem" | sed 's/.* \([0-9]*\)/\1/')

        if [ "$a" -ge -10000 ] && [ "$a" -le 10000 ] && [ "$b" -ge 0 ] && [ "$b" -le 10000 ]; then   
            answer=$(echo "$a $op $b" | bc)
            echo "$answer"
        else
            echo "Invalid problem"
        fi
    else
        echo "Invalid problem"
    fi
}

getplain() {
    cipher="$1"
    shift="$2"
    result=""

    for i in $(seq 1 26); do
    char=$(printf "%s" "$cipher" | cut -c "$i")

    # Handle uppercase letters
    if echo "$char" | grep -q '[A-Z]'; then
        ascii=$(printf "%d" "'$char")
        new_ascii=$(( (ascii - 65 + shift + 26) % 26 + 65 ))
        #echo "char is $char, new is $new_ascii"
        result="$result$(printf "%b" "\\$(printf '%03o' "$new_ascii")")"

    # Handle lowercase letters0
    elif echo "$char" | grep -q '[a-z]'; then
        ascii=$(printf "%d" "'$char")
        new_ascii=$(( (ascii - 97 + shift + 26) % 26 + 97 ))
        #echo "char is $char, new is $new_ascii"
        result="$result$(printf "%b" "\\$(printf '%03o' "$new_ascii")")"

    # Keep any other characters unchanged
    else
        result="$result$char"
    fi
done
    echo "$result"
}

caesar_decrypt() {
    ciphertext="$1"
    for shift in $(seq -13 -1) $(seq 1 13); do
        decrypted=$(getplain "$ciphertext" "$shift")
        #echo "in cae decrypted is $decrypted"
        #echo "len is ${#decrypted}"
        if echo "$decrypted" | grep -qE "^NYCUNASA\{[A-Za-z]{16}\}$"; then
            echo "$decrypted"
            exit 0
        fi
    done
    echo "Invalid problem"
}

while getopts p:t: opt 2>/dev/null; do
    case $opt in
        p)
            task_id="$OPTARG"
            ;;
        t)
            get_task_type="$OPTARG"
            ;;
        *)
            echo "$help" >&2
            exit 3
    esac
done

if [ $OPTIND -eq 1 ]; then
    echo "$help" >&2
fi

task_json=$(curl -s -X GET http://10.113.0.253/tasks/"$task_id" -H "Content-Type:application/json" --data "{\"type\": \"$get_task_type\"}")
#problem_id=$(echo "$task_json" | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p')
task_type=$(echo "$task_json" | sed -n 's/.*"type": *"\([^"]*\)".*/\1/p')
problem=$(echo "$task_json" | sed -n 's/.*"problem": *"\([^"]*\)".*/\1/p')
#echo "command is $0 $@"
echo "task json is $task_json"
echo "problem is $problem"
case "$get_task_type" in
    "JOIN_NYCU_CSIT")
        if [ "$get_task_type" != "$task_type" ]; then
            echo "Task type not match" >&2
            exit 1
        fi
        curl -s -X POST http://10.113.0.253/tasks/"$task_id"/submit -H "Content-Type:application/json" --data "{\"answer\": \"I Love NYCU CSIT\"}"
        exit 0
        ;;
    "MATH_SOLVER")
        if [ "$get_task_type" != "$task_type" ]; then
            echo "Task type not match" >&2
            exit 1
        fi
        math_answer=$(solve_math "$problem")
        echo "math answer is $math_answer"
        curl -s -X POST http://10.113.0.253/tasks/"$task_id"/submit -H "Content-Type:application/json" --data "{\"answer\": \"$math_answer\"}"
        exit 0
        ;;
    "CRACK_PASSWORD")
        if [ "$get_task_type" != "$task_type" ]; then
            echo "Task type not match" >&2
            exit 1
        fi
        decrypted_password=$(caesar_decrypt "$problem")
        echo "final decrypted is $decrypted_password"
        echo "final len is ${#decrypted_password}"
        #echo "$decrypted" | cut -c1-26
        curl -s -X POST http://10.113.0.253/tasks/"$task_id"/submit -H "Content-Type:application/json" --data "{\"answer\": \"$decrypted_password\"}"
        exit 0
        ;;
    *)
        echo "Invalid task type" >&2
        exit 2
esac