#!/bin/bash

INPUT_APK=$1
if [ "$INPUT_APK" == "" ]; then
    echo "ERROR: Please specify an input APK." 1>&2;
    exit -1
fi

FAILED_PREREQS=0
if [[ "$(which python3)" == "" ]]; then
    echo "ERROR: You do not have python3 installed." 1>&2;
    FAILED_PREREQS=1
else
    (python3 -c "import xml.etree.ElementTree" > /dev/null 2>&1) || {
        echo "ERROR: Could not import xml Python 3 module." 1>&2;
        FAILED_PREREQS=1
    }
fi

if [[ "$(which apktool)" == "" ]]; then
    echo "ERROR: apktool is not in your PATH." 1>&2;
    echo "Please view the installation instructions: https://ibotpeaches.github.io/Apktool/install/" 1>&2;
    FAILED_PREREQS=1
fi

if [[ "$(which keytool)" == "" ]]; then
    echo "ERROR: keytool is not in your PATH." 1>&2;
    echo "Please ensure that apktool is fully installed: https://ibotpeaches.github.io/Apktool/install/" 1>&2;
    FAILED_PREREQS=1
fi

if [[ "$(which jarsigner)" == "" ]]; then
    echo "ERROR: jarsigner is not in your PATH." 1>&2;
    echo "Please ensure that apktool is fully installed: https://ibotpeaches.github.io/Apktool/install/" 1>&2;
fi

if [[ "$FAILED_PREREQS" == "1" ]]; then
    echo "Failed prereqs. Exiting."
    exit -1
fi

echo "Input APK: $INPUT_APK"
echo ""
echo "-------------------- PATCH OPTIONS --------------------"
read -p "<!> Would you like to make the APK debuggable? [Y/n] " PATCH_DEBUGGABLE
if [[ "$PATCH_DEBUGGABLE" == "y" || "$PATCH_DEBUGGABLE" == "Y" ]]; then
    echo "Okay, making the APK debuggable."
    PATCH_DEBUGGABLE=y
else
    echo "Not making the APK debuggable."
fi
echo ""

read -p "<!> Would you like to disable certificate verification? [y/N] " PATCH_SECURITY_CONFIG
if [[ "$PATCH_SECURITY_CONFIG" == "y" || "$PATCH_SECURITY_CONFIG" == "Y" ]]; then
    echo "Okay, updating the APK security configuration."
    PATCH_SECURITY_CONFIG=y
else
    echo "Not updating the APK security configuration."
fi
echo ""

read -p "<!> How often (in minutes) should t:connect upload data to the cloud? [default: 60] " PATCH_UPLOAD_MINS
if [[ "$PATCH_UPLOAD_MINS" == "60" ]]; then
    echo "Will not update data upload rate."
else
    echo "Okay, will change the data upload rate to $PATCH_UPLOAD_MINS minutes"
fi
echo ""


echo "Beginning patch..."

EXTRACT_FOLDER="extract_$(basename $INPUT_APK | sed 's/.apk//')"
DEBUG_APK=$(basename $INPUT_APK | sed 's/.apk/-debug.apk/')

echo "Extracting APK to $EXTRACT_FOLDER"
DO_EXTRACT=y
if [ -d "$EXTRACT_FOLDER" ]; then
    echo "Folder $EXTRACT_FOLDER already exists."
    read -p "<!> Do you want to delete it and re-extract? [Y/n] " DO_EXTRACT
    if [[ "$DO_EXTRACT" == "y" || "$DO_EXTRACT" == "Y" ]]; then
        echo "Deleting $EXTRACT_FOLDER"
        rm -rf "$EXTRACT_FOLDER"
        DO_EXTRACT=y
    else
        echo "Okay, will use the already extracted folder."
        DO_EXTRACT=n
    fi
fi


if [[ "$DO_EXTRACT" == "y" ]]; then
    apktool d --use-aapt2 -o "$EXTRACT_FOLDER" "$INPUT_APK"
fi


echo "Applying APK modifications..."

MANIFEST_XML=$EXTRACT_FOLDER/AndroidManifest.xml
if [[ "$PATCH_DEBUGGABLE" == "y" || "$PATCH_SECURITY_CONFIG" == "y" ]]; then
    echo "Applying AndroidManifest patches"

    ATTRIB_PATCHES="'android:extractNativeLibs': 'true', "
    if [[ "$PATCH_DEBUGGABLE" == "y" ]]; then
        ATTRIB_PATCHES="${ATTRIB_PATCHES}'android:allowBackup': 'true', 'android:debuggable': 'true', "
    fi

    if [[ "$PATCH_SECURITY_CONFIG" == "y" ]]; then
        ATTRIB_PATCHES="${ATTRIB_PATCHES}'android:networkSecurityConfig': '@xml/network_security_config', "
    fi

    echo "Applying patches: $ATTRIB_PATCHES"

    python3 -c "
import xml.etree.ElementTree as etree
schema = 'http://schemas.android.com/apk/res/android'
etree.register_namespace('android', schema)
et = etree.parse('$MANIFEST_XML')
for child in et.getroot():
    if child.tag == 'application':
        print('Patching application tag in $MANIFEST_XML')
        patches = {
            $ATTRIB_PATCHES
        }
        for field in patches.keys():
            rawfield = field.replace('android:', '{' + schema + '}')
            if rawfield in child.attrib.keys():
                print('Deleting field for replacement:', rawfield)
                del child.attrib[rawfield]
        child.attrib.update(patches)
et.write('$MANIFEST_XML' + '_new', encoding='utf-8', xml_declaration=True)
    "
    if [ ! -f "${MANIFEST_XML}_new" ]; then
        echo "ERROR: Updated manifest file was not generated. Exiting."
        exit -1
    fi
    mv ${MANIFEST_XML}_new $MANIFEST_XML
fi

if [[ "$PATCH_SECURITY_CONFIG" == "y" ]]; then
    echo "Adding network_security_config"

    RES_XML_FOLDER=$EXTRACT_FOLDER/res/xml
    if [ ! -f "$RES_XML_FOLDER" ]; then
        mkdir -p "$RES_XML_FOLDER"
    fi

    NETWORK_SECURITY_CONFIG=$RES_XML_FOLDER/network_security_config.xml

    cat <<EOF > $NETWORK_SECURITY_CONFIG
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
   <base-config>
      <trust-anchors>
          <certificates src="system" />
          <certificates src="user" />
      </trust-anchors>
   </base-config>
</network-security-config>
EOF
fi

if [[ "$PATCH_UPLOAD_MINS" != "60" ]]; then
    echo "Applying data upload rate patch"

    # com.tandemdiabetes.tconnect.p088a.AppComponentStore
    APP_COMPONENT_STORE_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/tconnect/a/a.smali
    # private final long OneHourInMillis = 3600000
    OLD_INSTRUCTION_PREFIX="const-wide/32 p1,"
    OLD_INSTRUCTION_VALUE="0x36ee80"
    python3 -c "
orig = open('$APP_COMPONENT_STORE_SMALI').read()
old = '$OLD_INSTRUCTION_PREFIX $OLD_INSTRUCTION_VALUE'
if old in orig:
    val = hex(int($PATCH_UPLOAD_MINS) * 60 * 1000)
    orig = orig.replace(old, '$OLD_INSTRUCTION_PREFIX ' + str(val))
    print('Replaced $OLD_INSTRUCTION_VALUE with ' + str(val))
    open('$APP_COMPONENT_STORE_SMALI', 'w').write(orig)
else:
    print('Could not find '+old+' in $APP_COMPONENT_STORE_SMALI -- it may have already been patched.')
"
fi

echo "Done patching source files. You can make any other modifications now."
echo ""
read -p "<!> Continue to generate debug APK? [Y/n] " CONTINUE
if [[ "$CONTINUE" == "y" || "$CONTINUE" == "Y" ]]; then
    echo "Okay. continuing."
else
    exit -1;
fi

echo "Generating debug APK $DEBUG_APK"
apktool b --use-aapt2 -o "$DEBUG_APK" "$EXTRACT_FOLDER"

if [[ ! -f "$DEBUG_APK" ]]; then
    echo "ERROR: apktool failed to generate a debug APK."
    echo "Check the error output above."
    exit -1
fi

KEYSTORE=debug.keystore

if [ ! -f "$KEYSTORE" ]; then
    echo "Generating debug keystore at $KEYSTORE"
    echo "<!> When prompted, enter any password. You will be prompted to re-enter it when signing the APK."
    echo "<!> All non-password fields are optional. Type 'yes' when asked if your input was correct."

    keytool -genkey -v -keystore "$KEYSTORE" -alias alias_name -keyalg RSA -keysize 2048 -validity 10000
else
    echo "Existing debug keystore found"
fi

echo "Signing debug APK..."
echo "<!> When prompted, enter the password for $KEYSTORE"
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore "$KEYSTORE" "$DEBUG_APK" alias_name

echo "Done! You can now install $DEBUG_APK on your device."
echo ""
echo "IMPORTANT: If you currently have a release version of the t:connect app installed,"
echo "you MUST uninstall it before installing the patched version."
echo ""
read -p "<!> Would you like to install the patched APK now? [y/N] " INSTALL_NOW
if [[ "$INSTALL_NOW" == "y" || "$INSTALL_NOW" == "Y" ]]; then
    echo "Okay, running adb install"
    tmpfile=$(mktemp)
    (adb install $DEBUG_APK 2>&1 ) | tee $tmpfile
    if grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE" $tmpfile; then
        read -p "<!> The package was not installed. Would you like to delete the existing t:connect application and reinstall? [Y/n]" REINSTALL
        if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
            adb uninstall com.tandemdiabetes.tconnect
            echo "Retrying install..."
            adb install $DEBUG_APK
        else
            exit 1
        fi
    fi

    echo "All set!"
fi

echo "You'll need to re-login to the app, and also un-pair and re-pair your pump to your phone."
echo "Thanks for using this tool!"