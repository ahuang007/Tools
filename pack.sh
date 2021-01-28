#!/bin/bash

COLOR_RED='\033[31m'
COLOR_GREEN='\033[32m'
COLOR_RESET='\033[0m'

BUILD_TYPE=$1
SERVER_TYPE=$2
PACK_TYPE=$3
VERSION=$4

#   ServerName          ServerType
SERVER_LIST=(               \
    BattleServer        18  \
    BattleServerMgr     17  \
    MatchServer         16  \
    ChargeServer        6   \
    ChatCenterServer    14  \
    ChatServer          15  \
    DBServer            13  \
    DispatcherServer    2   \
    FriendServer        19  \
    GameServer          12  \
    GMServer            8   \
    MainGMServer        7   \
    LocalPublicServer   5   \
    LoginServer         11  \
    LogServer           9   \
    RankServer          21  \
    TeamServer          20  \
    TransferServer      3   \
)

SERVER_LIST_LEN=${#SERVER_LIST[@]}/2
SERVER_INDEX=0

PROJECT_NAME=xmoba-server
CUR_DIR=$(dirname $(readlink -f $0))
PROJECT_DIR=$CUR_DIR/..

SERVER_NAME=""
FILE_SERVER_IP="10.4.22.22"
FILE_SERVER_USER="dasheng"
FILE_SERVER_HTTP="http://dasheng.server.cc"
FILE_SERVER_DIR="/home/dasheng/gohttpserver/share"

case ${BUILD_TYPE} in
    debug|release)
    ;;
*)
    echo -e "Usage: $0 [debug|release]"
    echo -e "\t${COLOR_GREEN}debug  - deploy debug   server${COLOR_RESET}"
    echo -e "\t${COLOR_GREEN}deploy - deploy release server${COLOR_RESET}\n"
    exit 1
esac

SERVER_TYPE_CORRECT=false
if [[ "${SERVER_TYPE}" == "all" ]]; then
    SERVER_TYPE_CORRECT=true
else
    for ((i=0; i<${SERVER_LIST_LEN}; i=i+1));
    do
        if [[ "${SERVER_LIST[$i*2]}" == "${SERVER_TYPE}" ]]; then
            SERVER_TYPE_CORRECT=true
            SERVER_INDEX=${i}
        fi
    done
fi

if [[ "${SERVER_TYPE_CORRECT}" = "false" ]]; then
    echo -e "Usage: $0 $1 [all|ServerName]"
    echo -e "\t${COLOR_GREEN}all        - deploy all server${COLOR_RESET}"
    echo -e "\t${COLOR_GREEN}ServerName - deploy one server${COLOR_RESET}\n"
    exit 2
fi

case ${PACK_TYPE} in
    all|bin|csv|config|bincsv)
    ;;
*)
    echo -e "Usage: $0 $1 $2 [all|bin|csv|config|bincsv]"
    echo -e "\t${COLOR_GREEN}all    - pack all file${COLOR_RESET}"
    echo -e "\t${COLOR_GREEN}bin    - pack binary file${COLOR_RESET}\n"
    echo -e "\t${COLOR_GREEN}csv    - pack csv file${COLOR_RESET}\n"
    echo -e "\t${COLOR_GREEN}config - pack config file${COLOR_RESET}\n"
    echo -e "\t${COLOR_GREEN}bincsv - pack binary + csv file${COLOR_RESET}\n"
    exit 3
esac

if [[ "${VERSION}" == "" ]]; then
    echo -e "Usage: $0 $1 $2 $3 [version]"
    exit 4
fi

function pack() {
    SERVER_NAME=$1

    BIN_DIR=${PROJECT_DIR}/bin/${BUILD_TYPE}/bin/${SERVER_NAME}
    CONFIG_DIR=${PROJECT_DIR}/bin/config/template/${SERVER_NAME}
    CSV_DIR=${PROJECT_DIR}/bin/csv/bin/${SERVER_NAME}

    PACK_DIR=${CUR_DIR}/${VERSION}/${SERVER_NAME}

    rm -rf ${PACK_DIR}
    mkdir -p ${PACK_DIR}

    if [[ "${PACK_TYPE}" == "all" || "${PACK_TYPE}" == "bin" || "${PACK_TYPE}" == "bincsv" ]]; then
        if [ -d "${BIN_DIR}" ]; then
            cp -r ${BIN_DIR} ${PACK_DIR}/..
        fi
    fi

    if [[ "${PACK_TYPE}" == "all" || "${PACK_TYPE}" == "csv" || "${PACK_TYPE}" == "bincsv" ]]; then
        if [ -d "${CSV_DIR}" ]; then
            cp -r ${CSV_DIR} ${PACK_DIR}/..
        fi
    fi

    if [[ "${PACK_TYPE}" == "all" || "${PACK_TYPE}" == "config" ]]; then
        if [ -d "${CONFIG_DIR}" ]; then
            cp -r ${CONFIG_DIR} ${PACK_DIR}/..
        fi
    fi

    cd ${PACK_DIR}/..
    TAR_FILE_NAME=${SERVER_NAME}.tar.gz
    tar czvf ${TAR_FILE_NAME} ${SERVER_NAME} --exclude=*.exe --exclude=*.lib --exclude=*.dll --exclude=*.log;
    rm -rf ${PACK_DIR}
}

function pack_all() {
    for ((i=0; i<${SERVER_LIST_LEN}; i=i+1));
    do
        pack ${SERVER_LIST[$i*2]}
    done
}

function upload() {
    cd $CUR_DIR
    ssh ${FILE_SERVER_USER}@${FILE_SERVER_IP} "cd $FILE_SERVER_DIR && rm -rf $VERSION"
    scp -r ${VERSION} ${FILE_SERVER_USER}@${FILE_SERVER_IP}:${FILE_SERVER_DIR}
    rm -rf ${VERSION}
}

function gen_download_xml() {
    DOWNLOAD_LINE_PATTERN='\n\t<Service ServiceName="%s" ServiceType="%d" Version="%s" BinPath="%s" BinMD5="%s"/>'

    DOWNLOAD_LIST=""
    if [[ ${SERVER_TYPE} == "all" ]]; then
        for ((i=0; i<${SERVER_LIST_LEN}; i=i+1));
        do
            ServerName=${SERVER_LIST[$i*2]}
            ServiceType=${SERVER_LIST[$i*2+1]}
            BinPath="${FILE_SERVER_HTTP}/${VERSION}/${ServerName}.tar.gz"
            BinMD5=$(md5sum ${ServerName}.tar.gz | cut -d' ' -f1)
            DOWNLOAD_LINE=$(printf "${DOWNLOAD_LINE_PATTERN}" ${ServerName} ${ServiceType} ${VERSION} ${BinPath} ${BinMD5})

            if [[ DOWNLOAD_LIST == "" ]]; then
                DOWNLOAD_LIST=${DOWNLOAD_LINE}
            else
                DOWNLOAD_LIST=${DOWNLOAD_LIST}${DOWNLOAD_LINE}
            fi
        done
    else
        ServerName=${SERVER_TYPE}
        ServiceType=${SERVER_LIST[${SERVER_INDEX}*2+1]}
        BinPath="${FILE_SERVER_HTTP}/${VERSION}/${ServerName}.tar.gz"
        BinMD5=$(md5sum ${ServerName}.tar.gz | cut -d' ' -f1)
        DOWNLOAD_LIST=$(printf "${DOWNLOAD_LINE_PATTERN}" ${ServerName} ${ServiceType} ${VERSION} ${BinPath} ${BinMD5})
    fi

    cat <<EOF >download.xml
<?xml version="1.0" encoding="utf-8"?>
<!-- 进程资源下载列表  -->
<Config>
    <ServiceDownList>${DOWNLOAD_LIST}
    </ServiceDownList>
</Config>
EOF
}

function main() {
    if [[ ${SERVER_TYPE} == "all" ]]; then
        pack_all
    else
        pack ${SERVER_TYPE}
    fi

    gen_download_xml
    upload
}

main
