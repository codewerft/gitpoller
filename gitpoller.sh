#!/bin/bash -l

# Copyright 2014-2015 Ole Weidner (ole.weidner@codewerft.net)
# Licensed under the MIT License

# -----------------------------------------------------------------------------
# Global variables.
#
UPDATE_INTERVAL=300
BUILD_COMMAND="true"
REPOSITORY_URL=
CHECKOUT_DIR=
BRANCH=master
TOKEN=

# -----------------------------------------------------------------------------
# Print script usage help.
#
usage()
{
cat << EOF
usage: $0 options

This scripts clones and periodically updates a remote git repository.

OPTIONS:

   -d      Directory 

   -r      Git repository URL (currently only https:// supported)

   -b      Specific branch to check out (default: master)

   -t      OAuth token (optional for private repositories)

   -i      Update interval (default: 5m)
   
   -c      (Build) command to run after checkout / update

   -h      Show this message

EXAMPLES:

  Clone, periodially update and build the 'publish' branch of a Jekyll blog
hosted on GitHub to /var/www/myblog using the OAuth token 'SECRET':

./gitpoller.sh -d /var/www/myblog -r https://github.com/oweidner/oleweidner.com.git -b publish -t SECRET -c "jekyll build"


EOF
}

# -----------------------------------------------------------------------------
# Script entry point. 
#
while getopts â€œhd:r:b:t:i:c:â€ OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        d)
            CHECKOUT_DIR=$OPTARG
            ;;
        r)
            REPOSITORY_URL=$OPTARG
            ;;
        b)
            BRANCH=$OPTARG
            ;;
        t)
            TOKEN=$OPTARG
            ;;
        i)
            UPDATE_INTERVAL=$OPTARG
            ;;
        c)
            BUILD_COMMAND=$OPTARG
            ;;
        ?)
            usage
            exit
            ;;
     esac
done

# Make sure at least -d and -r were set.
if [[ -z $CHECKOUT_DIR ]] || [[ -z $REPOSITORY_URL ]] 
then
    usage
    exit 1
fi

# Construct the Git checkout URL.
CHECKOUT_URL=$REPOSITORY_URL
if ! [[ -z $TOKEN ]] ; then
    CHECKOUT_URL=`echo $REPOSITORY_URL | sed -e "s/:\/\//\:\/\/$TOKEN@/g"`
fi

# Make sure the checkout dir exists and we have write permission.
if ! [[ -d "$CHECKOUT_DIR" ]] ; then
  # Control will enter here if $DIRECTORY doesn't exist.
  echo " * Creating checkout directory $CHECKOUT_DIR"
  mkdir -p $CHECKOUT_DIR
fi

# Change into working directory and check if it is a valid git repository. 
cd $CHECKOUT_DIR
git status
if [[ $? != 0 ]] ; then
    # It is not. Clone the repository.
    git clone -b $BRANCH $CHECKOUT_URL .
fi

for (( ; ; ))
do
    # Update the repository
    printf " * Updating repository (git pull)"
    git pull
    if [[ $? != 0 ]] ; then
        # Git command failed. 
        printf " [FAILED]\n"
    else
        printf " [OK]\n"
    fi
    
    # Run the build command
    printf " * Building repository ($BUILD_COMMAND)"
    $BUILD_COMMAND
    if [[ $? != 0 ]] ; then
        # Build command failed. 
        printf " [FAILED]\n"
    else
        printf " [OK]\n"
    fi

    # Slee until the next interval
    sleep $UPDATE_INTERVAL
done

exit 0
