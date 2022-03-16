#!/bin/bash

###
# NOTE:
#   if you edit this file, you will also need to edit on server2.rvglobalsoft.com /home/rvdown/public_html/rvsitebuilder7cpinstall.sh
###

# delete
rm -f /usr/src/rvsb7cpplugin.tar.gz
rm -rf /usr/src/cpanel-plugin

# define var
readonly GHHEADERACCEPT="Accept: application/vnd.github.v3+json"
#readonly GHPROJECTURL="https://api.github.com/repos/rvsitebuilder-service/cpanel-plugin"
readonly GHPROJECTURL="https://api.github.com/repos/netway/rvsitebuilder-cpanel-plugin"
readonly OUTPUTTARFILE="/usr/src/rvsb7cpplugin.tar.gz"
LINKDOWNLOAD=""

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

# get link download
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

# download with wget
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

# unregister cpanel plugins
if [ -d "/usr/local/cpanel/base/frontend/paper_lantern/" ];
then
/usr/local/cpanel/scripts/uninstall_plugin /usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms_register_cpanel_plugin.tar.gz --theme=paper_lantern
rm -rf /usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms
fi

if [ -d "/usr/local/cpanel/base/frontend/jupiter/" ];
then
/usr/local/cpanel/scripts/uninstall_plugin /usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms_register_cpanel_plugin.tar.gz --theme=jupiter
rm -rf /usr/local/cpanel/base/frontend/jupiter/rvsitebuildercms
fi

# remove
rm -f /usr/local/cpanel/Cpanel/API/RVsitebuilderCMS.pm
rm -f /usr/src/rvsb7cpplugin.tar.gz
rm -rf /usr/src/rvsb7cpplugin
rm -f /usr/src/rvsitebuilder7cpinstall.sh
rm -f /usr/src/rvsitebuilder7cpuninstall.sh
