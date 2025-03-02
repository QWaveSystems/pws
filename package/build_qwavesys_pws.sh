#!/bin/bash
#

# Figure out how will the package be called
//ver=`git describe --tags --always`
ver="2.0.0-PWS-15"
package_name=qwavesyspws-$ver
echo "Version: $ver"
echo "Package name: $package_name"

# Set REMOTE_URL environment variable to the address where the package will be
# available for download. This gets written into package json file.
if [ -z "$REMOTE_URL" ]; then
    REMOTE_URL="QWaveSystems/PWS"
    echo "REMOTE_URL not defined, using default"
fi
echo "Remote: $REMOTE_URL"

if [ -z "$PKG_URL" ]; then
    PKG_URL="https://raw.githubusercontent.com/$REMOTE_URL/master/package/versions/$ver/$package_name.zip"
fi
echo "Package: $PKG_URL"

if [ -z "$DOC_URL" ]; then
    DOC_URL="https://github.com/$REMOTE_URL/blob/master/doc/reference.md"
fi
echo "Docs: $DOC_URL"
pushd ..
# Create directory for the package
outdir=package/versions/$ver/$package_name
srcdir=$PWD
rm -rf package/versions/$ver
mkdir -p $outdir

# Some files should be excluded from the package
cat << EOF > exclude.txt
.git
.gitignore
.travis.yml
package
EOF
# Also include all files which are ignored by git
git ls-files --other --ignored --exclude-standard --directory >> exclude.txt
# Now copy files to $outdir
rsync -a --exclude-from 'exclude.txt' $srcdir/ $outdir/
rm exclude.txt

# Get additional libraries (TODO: add them as git submodule or subtree?)
wget -q -O SoftwareSerial.zip https://github.com/plerup/espsoftwareserial/archive/2aebc169192fc2031319ad9ad066d5f7aef17caf.zip
unzip -q SoftwareSerial.zip
rm -rf SoftwareSerial.zip
mv espsoftwareserial-* SoftwareSerial
mv SoftwareSerial $outdir/libraries

# Do some replacements in platform.txt file, which are required because IDE
# handles tool paths differently when package is installed in hardware folder
cat $srcdir/platform.txt | \
sed 's/runtime.tools.xtensa-lx106-elf-gcc.path={runtime.platform.path}\/tools\/xtensa-lx106-elf//g' | \
sed 's/runtime.tools.esptool.path={runtime.platform.path}\/tools\/esptool//g' | \
sed 's/tools.esptool.path={runtime.platform.path}\/tools\/esptool/tools.esptool.path=\{runtime.tools.esptool.path\}/g' | \
sed 's/tools.mkspiffs.path={runtime.platform.path}\/tools\/mkspiffs/tools.mkspiffs.path=\{runtime.tools.mkspiffs.path\}/g' \
 > $outdir/platform.txt

# Zip the package
pushd package/versions/$ver
echo "Making $package_name.zip"
zip -qr $package_name.zip $package_name
rm -rf $package_name

# Calculate SHA sum and size
sha=`shasum -a 256 $package_name.zip | cut -f 1 -d ' '`
size=`/bin/ls -l $package_name.zip | awk '{print $5}'`
echo Size: $size
echo SHA-256: $sha

echo "Making package_qwavesyspws_index.json"
cat $srcdir/package/package_qwavesyspws_index.template.json | \
jq ".packages[0].platforms[0].version = \"$ver\" | \
    .packages[0].platforms[0].url = \"$PKG_URL\" |\
    .packages[0].platforms[0].archiveFileName = \"$package_name.zip\" |\
    .packages[0].platforms[0].checksum = \"SHA-256:$sha\" |\
    .packages[0].platforms[0].size = \"$size\" |\
    .packages[0].platforms[0].help.online = \"$DOC_URL\"" \
    > ./../package_qwavesyspws_index.json

popd
popd
