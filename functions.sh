#!/bin/bash

REALTIME_USER=realtime
REALTIME_DIR=/home/realtime
INASAFE_SOURCE_DIR=${REALTIME_DIR}/src/inasafe
REALTIME_DATA_DIR=${REALTIME_DIR}/analysis_data
SHAKE_DIR=${REALTIME_DIR}/shakemaps
SHAKE_EXTRACT_DIR=${REALTIME_DIR}/shakemaps-extracted
WEB_DIR=${REALTIME_DIR}/web

BTSYNC_IMAGE=docker-realtime-btsync
APACHE_IMAGE=docker-realtime-apache
SFTP_IMAGE=docker-realtime-sftp
INASAFE_REALTIME_IMAGE=docker-realtime-inasafe

function make_directories {

    if [ ! -d ${REALTIME_DIR} ]
    then
        mkdir -p ${REALTIME_DIR}
    fi
    sudo chown -R ${USER}.${USER} ${REALTIME_DIR}

    if [ ! -d ${REALTIME_DATA_DIR} ]
    then
        mkdir -p ${REALTIME_DATA_DIR}
    fi

    if [ ! -d ${SHAKE_DIR} ]
    then
        mkdir -p ${SHAKE_DIR}
    fi

    if [ ! -d ${SHAKE_EXTRACT_DIR} ]
    then
        mkdir -p ${SHAKE_EXTRACT_DIR}
    fi

    if [ ! -d ${WEB_DIR} ]
    then
        mkdir -p ${WEB_DIR}
    fi

}

function kill_container {

    NAME=$1

    if docker ps -a | grep ${NAME} > /dev/null
    then
        echo "Killing ${NAME}"
        docker kill ${NAME}
        docker rm ${NAME}
    else
        echo "${NAME} is not running"
    fi

}

function get_inasafe {

    echo ""
    echo "Pulling the latest InaSAFE Realtime from Github."
    echo "================================================"

    if [ ! -d ${INASAFE_SOURCE_DIR} ]
    then
        git clone --branch realtime http://github.com/AIFDR/inasafe.git --depth 1 --verbose ${INASAFE_SOURCE_DIR}
    else
        cd ${INASAFE_SOURCE_DIR}
        git pull origin realtime
        cd -
    fi
}

function build_apache_image {

    echo ""
    echo "Building Apache Image"
    echo "====================================="

    docker build -t aifdr/${APACHE_IMAGE} git://github.com/${ORG}/${APACHE_IMAGE}.git

}

function run_apache_container {

    echo ""
    echo "Running apache container"
    echo "====================================="

    kill_container ${APACHE_IMAGE}

    cp web/index.html ${WEB_DIR}/
    cp -r web/resource ${WEB_DIR}/

    docker run --name="${APACHE_IMAGE}" \
        --restart=always \
        -v ${WEB_DIR}:/var/www \
        -p 8080:80 \
        -d -t aifdr/${APACHE_IMAGE}

}

function build_sftp_server_image {

    echo ""
    echo "Building SFTP Server image"
    echo "====================================="

    docker build -t aifdr/${SFTP_IMAGE} git://github.com/${ORG}/${SFTP_IMAGE}.git

}


function run_sftp_server_container {

    echo ""
    echo "Running SFTP Server container"
    echo "====================================="

    kill_container  ${SFTP_IMAGE}

    docker run --name="${SFTP_IMAGE}" \
        --restart=always \
        -v ${SHAKE_DIR}:${SHAKE_DIR} \
        -p 9222:22 \
        -d -t aifdr/${SFTP_IMAGE}

}

function build_btsync_image {

    echo ""
    echo "Building btsync image"
    echo "====================================="

    docker build -t aifdr/${BTSYNC_IMAGE} git://github.com/${ORG}/${BTSYNC_IMAGE}.git

}

function run_btsync_container {

    echo ""
    echo "Running btsync container"
    echo "====================================="

    kill_container ${BTSYNC_IMAGE}

    docker run --name="${BTSYNC_IMAGE}" \
        --restart=always \
        -v ${REALTIME_DATA_DIR}:${REALTIME_DATA_DIR} \
        -p 8888:8888 \
        -p 55555:55555 \
        -d -t aifdr/${BTSYNC_IMAGE}

}


function build_realtime_image {
    echo ""
    echo "Building InaSAFE Realtime Image"
    echo "====================================="

    docker build -t aifdr/${INASAFE_REALTIME_IMAGE} git://github.com/${ORG}/${INASAFE_REALTIME_IMAGE}.git
}

function get_credentials {
    docker cp ${SFTP_IMAGE}:/credentials .
    cat credentials
    rm credentials
}

function show_credentials {
    echo ""
    echo "Login details for SFTP container:"
    echo "====================================="
    # Note you can run this command any time after the container
    # is started and all containers started will have these
    # same credentials so you should be able to safely destroy
    # and recreate this container
    get_credentials
}

function get_sftp_local_ip {
    docker inspect ${SFTP_IMAGE} | grep IPAddress | cut -d '"' -f 4
}

function get_sftp_local_port {
    docker inspect ${SFTP_IMAGE} | grep /tcp -m 1 | cut -d ':' -f 1 | cut -d '"' -f 2 | cut -d '/' -f 1
}

function get_sftp_user_name {
    get_credentials | cut -d ':' -f 2 | cut -d ' ' -f 2
}

function get_sftp_user_password {
    get_credentials | cut -d ':' -f 3 | cut -d ' ' -f 2
}

function get_sftp_base_path {
    docker inspect ${SFTP_IMAGE} | grep ${SHAKE_DIR} -m 1 | cut -d ':' -f 1 | cut -d '"' -f 2
}
