for i in H e l l o , 0 W o r l d ! 1
do
    if [[ "$i"x == "0"x ]] then
        echo -e "\033[3$((RANDOM%8+1))m \033[0m\c"
    elif [[ "$i"x == "1"x ]] then
        echo -e "\033[3$((RANDOM%8+1))m \033[0m"
    else
        echo -e "\033[3$((RANDOM%8+1))m$i\033[0m\c"
    fi
done

function proxy() {
    export http_proxy="http://127.0.0.1:8010"
    export https_proxy="http://127.0.0.1:8010"
}

function ss() {
    arg="$1"

    case $arg in
        restart)
            sudo systemctl restart shadowsocks@config
            ;;
        info)
            sudo systemctl status shadowsocks@config
            ;;
        stop)
            sudo systemctl stop shadowsocks@config
            ;;
        config)
            config_url=`cat /etc/shadowsocks/config.json | grep server\": | sed 's/.*\"server\":\"\(.*\)\",/\1/'`
            echo Server: $config_url
            ;;
        list)
            ls /etc/shadowsocks/ | grep -Ev "config|example"
            ;;
        to)
            config_file="$2"

            if [ -f /etc/shadowsocks/$config_file.json ]; then
                sudo cp -f /etc/shadowsocks/$config_file.json /etc/shadowsocks/config.json
                sudo systemctl restart shadowsocks@config
            elif [ -z "$config_file" ]; then
                echo Your input is empty.
            else
                echo $config_file could not be found.
            fi
            ;;
        test)
            server_config="$2"
            
            if [ -z "$server_config" ]; then
                server_config='config'
            fi

            if [ -f /etc/shadowsocks/$server_config.json ]; then
                test_url=`cat /etc/shadowsocks/${server_config}.json | grep server\": | sed 's/.*\"server\":\"\(.*\)\",/\1/'`

                echo Server: $test_url
                ping $test_url
            else
                echo $server_config config could not be found.
            fi
            ;;
        *)
            if [ -z "$1" ]; then
                echo The arg is empty.
            else
                echo The arg $1 unknown.
            fi
            ;;
    esac
}
