#!/bin/bash

###
# NOTE:
#   if you edit this file, you will also need to edit on server2.rvglobalsoft.com /home/rvdown/public_html/rvsitebuilder7cpinstall.sh
###

# delete old path
rm -f /usr/src/rvsb7cpplugin.tar.gz
rm -rf /usr/src/cpanel-plugin
rm -f /usr/src/rvlicense.pm
rm -f /usr/src/rvsitebuilder7installer.pl
rm -f /usr/src/rvsitebuilder7installer.tar.gz
rm -f /usr/src/rvsitebuilder7install.sh
rm -f /usr/src/rvsitebuilder7latestinstall.sh
rm -f /usr/src/rvsitebuilder7uninstall.sh
# delete new
rm -rf /usr/src/rvsb7cpplugin

echo -e "\n"

VERSION="stable"
if [ ! -z "$1" ];
then
	VERSION=$1
fi

readonly GHHEADERACCEPT="Accept: application/vnd.github.v3+json"
#readonly GHPROJECTURL="https://api.github.com/repos/rvsitebuilder-service/cpanel-plugin"
readonly GHPROJECTURL="https://api.github.com/repos/netway/rvsitebuilder-cpanel-plugin"
readonly OUTPUTTARFILE="/usr/src/rvsb7cpplugin.tar.gz"
LINKDOWNLOAD=""

echo -e "Version to install $VERSION\n"

# get token for download
RESPONSE=$(curl \
	--silent \
	--header "Allow-GATracking: true" \
 	--header "RV-Product: rvsitebuilder" \
	--request GET \
	"https://files.mirror1.rvsitebuilder.com/download/getdownloadtoken" |
    grep '"token":' | \
    sed -E 's/.*"([^"]+)".*/\1/' )
VAR=$(echo $RESPONSE | awk -F"--" '{print $1,$2}')
set -- $VAR
IVHEX=$(echo $1 | sed  -E 's/\\//g')
MESSAGE=$(echo $2 | sed  -E 's/\\//g')
KEYHEX='61726e7574406e65747761792e636f2e7468' #bintohex from arnut@netway.co.th
if [ -z $IVHEX ] || [ -z $KEYHEX ]
then
    echo "Cannot get token for download."
	exit 1
fi
GHTOKEN=$(echo -n "$MESSAGE" | openssl aes-256-cbc -d -a -A -K "$KEYHEX" -iv "$IVHEX")
if [ -z GHTOKEN ]
then
    echo "Cannot generate token for download."
	exit 1
fi

readonly GHHEADERAUTH="Authorization: token $GHTOKEN"

<<comment
latest -download the latest release version
stable -download stable version that latest release doesn't look alpha , beta
beta,alpha -download the latest released version and the name contains the words "alpha" or "beta"
version specific (vx.x.x or vx.x.x-beta.xxx) -download according to the specified version
comment

if [ $VERSION == 'latest' ]
then
	GETVERSION=$(curl \
	--silent \
	--header "$GHHEADERAUTH"\
 	--header "$GHHEADERACCEPT" \
	--request GET \
	"$GHPROJECTURL/releases?per_page=1" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/' )
	LINKDOWNLOAD="$GHPROJECTURL/tarball/$GETVERSION"
elif [ $VERSION == 'stable' ]
then
	LINKDOWNLOAD=$(curl \
        --silent \
        --show-error \
        --header "$GHHEADERAUTH"\
        --header "$GHHEADERACCEPT" \
        --request GET \
        "$GHPROJECTURL/releases?per_page=100" \
        | grep -Po "tarball.*v[0-9]+\.[0-9]+\.[0-9]+\"" \
        | head -n 1 \
        | cut -d : -f 2,3 \
        | tr -d \", )
elif [ $VERSION == 'beta' ] || [ $VERSION == 'alpha' ]
then
	LINKDOWNLOAD=$(curl \
        --silent \
        --show-error \
        --header "$GHHEADERAUTH"\
        --header "$GHHEADERACCEPT" \
        --request GET \
        "$GHPROJECTURL/releases?per_page=100" \
        | grep "tarball.*v.*$VERSION.*" \
        | head -n 1 \
        | cut -d : -f 2,3 \
        | tr -d \", )
elif [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+\-(beta|alpha)\.[0-9]+ ]]
then
	LINKDOWNLOAD="$GHPROJECTURL/tarball/$VERSION"
else
	echo "Version not match in rvsitebuilder7 repository! Bye."
	exit 1
fi

if [ -z "$LINKDOWNLOAD" ]
then
	echo -e "Not found link for download according to the specified version (version $VERSION)."
	exit 1
fi

echo "Link download: $LINKDOWNLOAD"
wget \
	--no-check-certificate \
	--header="$GHHEADERAUTH" \
	--header="$GHHEADERACCEPT" \
	$LINKDOWNLOAD \
	--output-document $OUTPUTTARFILE
if [[ "$?" != 0 ]]; then
    echo "Error downloading file from url $LINKDOWNLOAD"
	exit 1
else
    echo "Download Success"
fi

# extract installer
mkdir -p /usr/src/rvsb7cpplugin
tar zxvf $OUTPUTTARFILE -C /usr/src/rvsb7cpplugin --strip-components=1

# write rvsb7cpanelpluginversion.txt;
CPVERSION=$(echo $LINKDOWNLOAD | sed -E 's/.*tarball\///')
echo $CPVERSION > /usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms/rvsb7cpanelpluginversion.txt

# install rvsitebuilder
perl /usr/src/rvsb7cpplugin/rvsitebuilder7installer.pl "$VERSION"