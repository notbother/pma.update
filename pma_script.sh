usage() {
    echo "usage: sh pma-update.sh [-hvf] [-r version]";
    echo "-h            this help";
    echo "-v            output all warnings";
    echo "-f            force download, even if this version is installed already";
    echo "-r version    choose a different version than the latest.";
}

if [ -f $CONFIG_FILE ]; then
    command . $CONFIG_FILE;
fi


log() {
    if [ $LOGLEVEL -gt 0 ]; then
        echo "$@";
    fi
}


info() {
    if [ $LOGLEVEL -eq 2 ]; then
        echo "$@";
    fi
}

# Options
params="$(getopt -o hvfr: -l help --name "$cmdname" -- "$@")"

if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$params"
unset params

while true
do
    case "$1" in
        -v) LOGLEVEL=2;;
        -f) FORCE=on;;
        -r) VERSION="$2"; shift;;
        -h|--help)
            usage
            exit;;
        --)
            shift
            break;;
        *)
            usage;;
    esac
    shift
done


if [ -z "$LOCATION" -o -z "$PMA" ]; then
    log "Please, check your settings. The variables LOCATION, PMA are mandatory!";
    exit 1;
fi


if [ -f $LOCATION/$PMA/README ]; then
    VERSIONLOCAL=$(sed -n 's/^Version \(.*\)$/\1/p' $LOCATION/$PMA/README);
    info "Found local installation version" $VERSIONLOCAL;
else
    log "Did not found a working installation. Please, check the script settings.";
    exit 1;
fi



# If $USER or $GROUP empty, read from installed phpMyAdmin
if [ -z "$USER" ]; then
    USER=$(stat -c "%U" $LOCATION/$PMA/index.php);
fi
if [ -z "$GROUP" ]; then
    GROUP=$(stat -c "%G" $LOCATION/$PMA/index.php);
fi


if [ -z "$USER" -o -z "$GROUP" ]; then
    log "Please, check your settings. Set USER and GROUP, please!";
    exit 1;
fi

if [ -z "$LANGUAGE" ]; then
    LANGUAGE="all-languages";
fi



if [ -n "$VERSION" ]; then

    #Check the versions
    if [ "$VERSION" = "$VERSIONLOCAL" ]; then
        info "phpMyAdmin $VERSIONLOCAL is already installed!";
        if [ "$FORCE" != "on" ]; then
            exit 0;
        fi
        info "I will install it anyway.";
    fi
    
else

    VERSION=$(wget -q -O /tmp/phpMyAdmin_Update.html $VERSIONLINK && sed -ne '1p' /tmp/phpMyAdmin_Update.html);


    #Check the versions
    if [ "$VERSION" = "$VERSIONLOCAL" ]; then
        info "You have the latest version of phpMyAdmin installed!";
        if [ "$FORCE" != "on" ]; then
            exit 0;
        fi
        info "I will install it anyway.";
    fi
fi


WGETLOG="-q";
VERBOSELOG="";
if [ "$CTYPE" = "tar.gz" ]; then
    TARLOG="xzf";
elif [ "$CTYPE" = "tar.bz2" ]; then
    TARLOG="xjf";
fi
if [ $LOGLEVEL -eq 2 ]; then
    WGETLOG="-v";
    VERBOSELOG="-v";
    TARLOG=${TARLOG}v;
fi


# Start update
if [ -n "$VERSION" ]; then

    cd $LOCATION;
    MYLOCATION=`pwd`;

    if [ $MYLOCATION != $LOCATION ]; then
    
        log "An error occured while changing the directory. Please check your settings! Your given directory: $LOCATION";
        pwd;

    else
    
        wget $WGETLOG --directory-prefix=$LOCATION $DOWNLOADURL/$VERSION/phpMyAdmin-$VERSION-$LANGUAGE.$CTYPE
        
        if [ -f "$LOCATION/phpMyAdmin-$VERSION-$LANGUAGE.$CTYPE" ]; then

            tar $TARLOG phpMyAdmin-$VERSION-$LANGUAGE.$CTYPE || exit 1;
            mv $VERBOSELOG $LOCATION/$PMA/config.inc.php $LOCATION/phpMyAdmin-$VERSION-$LANGUAGE/
            rm -R $VERBOSELOG $LOCATION/$PMA
            mv $VERBOSELOG $LOCATION/phpMyAdmin-$VERSION-$LANGUAGE $LOCATION/$PMA
            chown -R $VERBOSELOG $USER:$GROUP $LOCATION/$PMA
            # Remove downloaded package
            rm $VERBOSELOG phpMyAdmin-$VERSION-$LANGUAGE.$CTYPE
            # Remove setup-folder for security issues
            rm -R $VERBOSELOG $LOCATION/$PMA/setup

            if [ $DELETE -eq 1 ]; then
                # Remove examples-folder
                rm -R $VERBOSELOG $LOCATION/$PMA/examples
            fi

            log "PhpMyAdmin successfully updated from version $VERSIONLOCAL to $VERSION in $LOCATION. Enjoy!"
            
        else
        
            log "An error occured while downloading phpMyAdmin. Downloading unsuccessful from: $DOWNLOADURL/$VERSION/phpMyAdmin-$VERSION-$LANGUAGE.$CTYPE.";
        
        fi
    fi
else

    log "Something went wrong while getting the version of phpMyAdmin. :( "
    log "Maybe this link here is dead: $VERSIONLINK";
    
fi
