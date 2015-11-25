#!/bin/bash -e
# This script uses component_settings

LOG_DIR=logs
LOG_FILE=$LOG_DIR/log_`date +%Y-%m-%d.%H:%M:%S`
KSGEN_DIR=ksgen_conf

EXIT_NO_ARGS=42
EXIT_HELP=13
EXIT_NO_TESTER=36
EXIT_END=95

PRODUCT=rhos
PRODUCT_REPO=poodle

function install_docker() {
    echo "====== Installing Docker ======"
    if rpm -qa | grep -q docker; then
        echo "Docker already installed"
    else
        sudo dnf install -y docker
    fi
    sudo systemctl start docker
}

function remove_container() {
    echo  "====== Removing container: $CONTAINER_NAME ======"
    echo "Stopping container: " && sudo docker stop $CONTAINER_NAME
    echo "Removing container: " && sudo docker rm $CONTAINER_NAME
    exit $EXIT_END
}

function run_container() {
    echo  "====== Running container with khaleesi ======
NOTE: If this your first time using the wrapper,
It might take some time to download the container image"
    sudo docker run --name $CONTAINER_NAME -id abregman/khaleesi-centos:master
}

function ensure_component() {
    echo  "====== Ensure component exists ======"
    if [ -z $COMPONENT ]; then
	if [ -z $COMPONENT_URL ]; then
	    echo "No component or url provided. Outrageous!"
	    echo "Remmember, you can either use component_settings file or pass
arguments using cli with -c component or -git component_url "
            remove_container
	    exit $EXIT_NO_ARGS
	else
            if [ -z $BRANCH ]; then
		echo "When using a remote component, a branch should also 
be provided with -b <branch_name>"
	        exit $EXIT_NO_ARGS
	    else
                COMPONENT=`basename $COMPONENT_URL .git`
		git clone -v $COMPONENT_URL || remove_container
		pushd $COMPONENT && git checkout origin/$BRANCH && popd
	    fi
	fi
    else
       echo "Found $COMPONENT!"
    fi
}

function parse_options() {
    echo  "====== Parse Options ======"
    # Set Branch
    pushd $COMPONENT > /dev/null
        if [ ! -z $BRANCH ]; then
	    echo "*Checkout BRANCH: $BRANCH"
            git checkout $BRANCH
	else
	    BRANCH=$(basename `git name-rev --name-only HEAD`)
            echo "*Detected branch: $BRANCH"
	fi
    popd > /dev/null

    # Product
    echo "*Product: $PRODUCT"
    # Product Version
    PRODUCT_VERSION=`echo $BRANCH | grep -o [0-9].[0-9]`
    echo "*Product version: $PRODUCT_VERSION"
}

function set_options() {
    echo  "====== Setting options in $KSGEN_DIR/$TESTER ======"
    # Set product
    sed -i -e "/product=/ s/=.*/=$PRODUCT \\\/" $KSGEN_DIR/$TESTER
    # Set product version
    sed -i -e "/product-version=/ s/=.*/=$PRODUCT_VERSION \\\/" $KSGEN_DIR/$TESTER
    # Set product repo
    sed -i -e "/product-repo=/ s/=.*/=$PRODUCT_REPO \\\/" $KSGEN_DIR/$TESTER
    # Set component
    sed -i -e "/installer-component=/ s/=.*/=$COMPONENT \\\/" $KSGEN_DIR/$TESTER
    # Set tester
    sed -i -e "/tester=/ s/=.*/=$TESTER \\\/" $KSGEN_DIR/$TESTER
    echo  "*Done"
}

function copy_component() {
    echo  "====== Copying $COMPONENT to container ======"
    sudo docker cp $COMPONENT $CONTAINER_NAME:/
    echo "Copied $COMPONENT to $CONTAINER_NAME"
}

function ensure_tester() {
    echo  "====== Ensure tester supported by Khaleesi ======"
    if [ -z $TESTER ]; then
	echo "You didn't specify tester. Blasphemy!"
        echo "Remmember, you can either use component_settings file or pass
arguments using cli with -t tester_type "
        remove_container
        exit $EXIT_NO_ARGS
    else
	if [ ! -e $KSGEN_DIR/$TESTER ]; then
	    echo "Khaleesi doesn't support $TESTER tests at the moment."
            remove_container
            exit $EXIT_NO_ARGS
	else
            echo "Tester: $TESTER is supported!"
	fi
    fi
}

function copy_tester_settings() {
    echo  "====== Copying $TESTER ksgen settings into container ======"
    sudo docker cp $KSGEN_DIR/$TESTER $CONTAINER_NAME:/khaleesi/
    sudo docker exec $CONTAINER_NAME chmod +r /khaleesi/$TESTER
    echo "Copied $COMPONENT to $CONTAINER_NAME"
}

function update_redhat-release() {
    # This updates /etc/redhat-release in order for rhos-release to work
    echo  "====== Updating redhat-release in container: $CONTAINER_NAME"
    sudo docker exec $CONTAINER_NAME /bin/sh -c "echo 'Red Hat Enterprise Linux Server release 7.1 (Maipo)' > /etc/redhat-release"
    echo "Updated to rhel 7.1"
}

#===================== Main ========================================

mkdir -p $LOG_DIR
exec &> >(tee -a "$LOG_FILE")

if [ -f component_settings ]; then
    source component_settings
fi

# Generate random alphanumeric string for unique container name
random_str=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1`
CONTAINER_NAME=khaleesi_$random_str

while [ $# -ge 1 ]
do
    key="$1"
    case $key in
        -c|--component)
        COMPONENT="$2"
	shift
        ;;
        -git|--component_url)
        COMPONENT_URL="$2"
	shift
        ;;
        -t|--tester)
        TESTER="$2"
	shift
        ;;
        -b|--branch)
        BRANCH="$2"
	shift
        ;;
        -p|--product)
        PRODUCT="$2"
	shift
        ;;
        -pv|--product-version)
        PRODUCT_VERSION="$2"
	shift
        ;;
        -pr|--product-repo)
        PRODUCT_REPO="$2"
	shift
        ;;
        -h|--help)
        echo "USAGE: component_test.sh -c <component> -t <tester_type> [OPTIONS]

OPTIONS:
	 -git,--component_url   component_url
         -b,--branch            branch
	 -p,--product           product (rhos,rdo)
	 -pv,--product-version  product version (5.0, 6.0, 7.0, 8.0)
	 -pr,--product-repo     product repo type
Examples:
Run pep8 tests in neutron: ./component_test.sh -c neutron -t pep8"
        exit $EXIT_HELP
        ;;
        *)
        shift
	;;
    esac
done

install_docker 
run_container 
ensure_component 
parse_options
copy_component
ensure_tester
set_options
copy_tester_settings
update_redhat-release
#remove_container
