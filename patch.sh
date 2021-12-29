#!/bin/bash

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

EXPECTED_PACKAGE=com.tandemdiabetes.tconnect
APK_VERSION_1_2="1.2"
APK_VERSION_1_4="1.4 (c8)"
APK_VERSION_1_6="1.6 (11a)"
EXPECTED_APK_VERSIONS=("$APK_VERSION_1_2") # "$APK_VERSION_1_4" "$APK_VERSION_1_6")

echo "   t:connect Patcher: version 1.5   "
echo " github.com/jwoglom/tconnectpatcher "
echo "------------------------------------"
echo ""
echo "This is a patcher utility which adds additional configuration"
echo "options to the Tandem Diabetes t:connect Android app."
echo ""
echo "Currently only the following versions are supported:"
for v in "${EXPECTED_APK_VERSIONS[@]}"; do
    echo " - $v"
done
echo ""

INPUT_APK=$1
if [ "$INPUT_APK" == "" ]; then
    echo "ERROR: Please specify an APK." 1>&2;
    echo "This APK should be $EXPECTED_PACKAGE"
    exit -1
fi

ADVANCED=n
if [[ "$2" == "--advanced" ]]; then
    ADVANCED=y
fi

echo "Input APK: $INPUT_APK"
echo ""
echo "-------------------- PATCH OPTIONS --------------------"


PATCH_DEBUGGABLE=y
PATCH_SECURITY_CONFIG=y
PATCH_BT_LOGGING=y
if [[ "$ADVANCED" == "y" ]]; then
    read -p "<!> Would you like to make the APK debuggable? [Y/n] " PATCH_DEBUGGABLE
    if [[ "$PATCH_DEBUGGABLE" == "y" || "$PATCH_DEBUGGABLE" == "Y" || "$PATCH_DEBUGGABLE" == "" ]]; then
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


    read -p "<!> Modify to log bluetooth data? [y/N] " PATCH_BT_LOGGING
    if [[ "$PATCH_BT_LOGGING" == "y" || "$PATCH_BT_LOGGING" == "Y" ]]; then
        echo "Okay, will patch bluetooth logging."
        PATCH_BT_LOGGING=y
    else
        echo "Not patching bluetooth logging."
    fi
    echo ""
fi

read -p "<!> How often (in minutes) should t:connect upload data to the cloud? [default: 60] " PATCH_UPLOAD_MINS
if [[ "$PATCH_UPLOAD_MINS" == "60" ]]; then
    echo "Will not update data upload rate."
elif [[ "$PATCH_UPLOAD_MINS" == "" ]]; then
    PATCH_UPLOAD_MINS=60
    echo "Will not update data upload rate."
else
    echo "Okay, will change the data upload rate to $PATCH_UPLOAD_MINS minutes"
fi
echo ""


echo "Beginning patch..."

EXTRACT_FOLDER="extract_$(basename $INPUT_APK | sed 's/.apk//')"
PATCHED_APK=$(basename $INPUT_APK | sed 's/.apk/-patched.apk/')

echo "Extracting APK to $EXTRACT_FOLDER"
DO_EXTRACT=y
if [ -d "$EXTRACT_FOLDER" ]; then
    echo "Folder $EXTRACT_FOLDER already exists."
    read -p "<!> Do you want to delete it and re-extract? [y/N] " DO_EXTRACT
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

MANIFEST_XML=$EXTRACT_FOLDER/AndroidManifest.xml
python3 -c "
import sys
import xml.etree.ElementTree as etree
schema = 'http://schemas.android.com/apk/res/android'
etree.register_namespace('android', schema)
et = etree.parse('$MANIFEST_XML')
root = et.getroot()
if root.attrib['package'].lower() != '$EXPECTED_PACKAGE'.lower():
    print('Found package ID:', root.attrib['package'])
    sys.exit(-1)
else:
    print('Package ID matches')
    sys.exit(0)
" || {
    echo ""
    echo "ERROR: The APK provided has an unexpected package name. The patcher will not work properly." 1>&2;
    echo "Please pass an APK with package name $EXPECTED_PACKAGE to this tool." 1>&2;
    exit -1
}

APK_VERSION=$(grep 'versionName:' $EXTRACT_FOLDER/apktool.yml | sed "s/\(.*\)\: \(.*\)/\2/" | tr -d '"' | tr -d "'")

version_ok=false
for v in "${EXPECTED_APK_VERSIONS[@]}"; do
    if [[ "$APK_VERSION" == "$v" ]]; then
        version_ok=true
    fi
done

if [[ "$version_ok" == "false" ]]; then
    echo ""
    echo "WARNING: The APK provided has an unexpected version. The patcher may not work properly." 1>&2;
    echo "Found version: $APK_VERSION" 1>&2;
    echo "Expected versions: ${EXPECTED_APK_VERSIONS[@]}" 1>&2;
    echo ""
else
    echo "Found APK version $APK_VERSION"
fi



echo "Applying APK modifications..."

echo "Applying AndroidManifest patches"

# Fix 'Failure [INSTALL_FAILED_INVALID_APK: Failed to extract native libraries, res=-2]'
# see https://github.com/iBotPeaches/Apktool/issues/1626
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

    if [[ "$APK_VERSION" == "$APK_VERSION_1_2" ]]; then
        # com.tandemdiabetes.tconnect.p088a.AppComponentStore
        APP_COMPONENT_STORE_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/tconnect/a/a.smali
        # private final long OneHourInMillis = 3600000
        OLD_INSTRUCTION_PREFIX="const-wide/32 p1,"
        OLD_INSTRUCTION_VALUE="0x36ee80" # 3600000

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
    elif [[ "$APK_VERSION" == "$APK_VERSION_1_4" ]]; then
        # AppComponentStore.kt Runnable
        APP_COMPONENT_STORE_RUNNABLE_SMALI=$EXTRACT_FOLDER/smali_classes2/com/tandemdiabetes/tconnect/a/a\$d.smali
        # new PeriodicWorkRequest.Builder(PeriodicUploadTriggerWorker.class, 60, TimeUnit.MINUTES)
        OLD_INSTRUCTION_PREFIX="const-wide/16 v5,"
        OLD_INSTRUCTION_VALUE="0x3c" # 60

        python3 -c "
orig = open('$APP_COMPONENT_STORE_RUNNABLE_SMALI').read()
old = '$OLD_INSTRUCTION_PREFIX $OLD_INSTRUCTION_VALUE'
if old in orig:
    val = hex(int($PATCH_UPLOAD_MINS))
    orig = orig.replace(old, '$OLD_INSTRUCTION_PREFIX ' + str(val))
    print('Replaced $OLD_INSTRUCTION_VALUE with ' + str(val))
    open('$APP_COMPONENT_STORE_RUNNABLE_SMALI', 'w').write(orig)
else:
    print('Could not find '+old+' in $APP_COMPONENT_STORE_RUNNABLE_SMALI -- it may have already been patched.')
"
    elif [[ "$APK_VERSION" == "$APK_VERSION_1_6" ]]; then
        # AppComponentStore.kt Runnable
        APP_COMPONENT_STORE_RUNNABLE_SMALI=$EXTRACT_FOLDER/smali_classes2/com/tandemdiabetes/tconnect/a/a\$d.smali
        # new PeriodicWorkRequest.Builder(PeriodicUploadTriggerWorker.class, 60, TimeUnit.MINUTES)
        OLD_INSTRUCTION_PREFIX="const-wide/16 v5,"
        OLD_INSTRUCTION_VALUE="0x3c" # 60

        python3 -c "
orig = open('$APP_COMPONENT_STORE_RUNNABLE_SMALI').read()
old = '$OLD_INSTRUCTION_PREFIX $OLD_INSTRUCTION_VALUE'
if old in orig:
    val = hex(int($PATCH_UPLOAD_MINS))
    orig = orig.replace(old, '$OLD_INSTRUCTION_PREFIX ' + str(val))
    print('Replaced $OLD_INSTRUCTION_VALUE with ' + str(val))
    open('$APP_COMPONENT_STORE_RUNNABLE_SMALI', 'w').write(orig)
else:
    print('Could not find '+old+' in $APP_COMPONENT_STORE_RUNNABLE_SMALI -- it may have already been patched.')
"
    else
        echo "ERROR: unable to perform upload patch on this version."
        exit -1
    fi
fi

# This doesn't allow the app to launch.
if [[ "$APK_VERSION" == "$APK_VERSION_1_4" ]]; then
    echo "Nullifying MessageGuardException..."

    PROTECTED_APP_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/tconnect/ProtectedApp.smali

    MESSAGE_GUARD_INVOCATION_1='invoke-direct {v1, v2, v0}, Lcom/tandemdiabetes/tconnect/MessageGuardException;-><init>(Ljava/lang/String;Ljava/lang/Throwable;)V\n\n    throw v1'
    MESSAGE_GUARD_INVOCATION_2='invoke-direct {v4, v5, v1}, Lcom/tandemdiabetes/tconnect/MessageGuardException;-><init>(Ljava/lang/String;Ljava/lang/Throwable;)V\n\n    throw v4'
    python3 -c "
orig = open('$PROTECTED_APP_SMALI').read()
a = '$MESSAGE_GUARD_INVOCATION_1'
b = '$MESSAGE_GUARD_INVOCATION_2'
if a in orig and b in orig:
    orig = orig.replace(a, 'return-void')
    orig = orig.replace(b, 'return-void')
    print('Removed '+a)
    print('Removed '+b)

    open('$PROTECTED_APP_SMALI', 'w').write(orig)
else:
    print('Could not find '+a+' or '+b+' in $PROTECTED_APP_SMALI -- it may have already been patched.')
"
fi

# This doesn't allow the app to launch.
if [[ "$APK_VERSION" == "$APK_VERSION_1_6" ]]; then
    echo "Nullifying MessageGuardException..."

    PROTECTED_APP_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/tconnect/ProtectedApp.smali

    MESSAGE_GUARD_INVOCATION_1='new-instance v0, Lcom/tandemdiabetes/tconnect/MessageGuardException;'
    MESSAGE_GUARD_INVOCATION_2='sget-object v1, Lcom/tandemdiabetes/tconnect/ProtectedApp;->dD:Ljava/lang/String;'
    MESSAGE_GUARD_INVOCATION_3='invoke-direct {v0, p1, v1}, Lcom/tandemdiabetes/tconnect/MessageGuardException;-><init>(Ljava/lang/Throwable;Ljava/lang/String;)V'
    MESSAGE_GUARD_THROW='throw v0'
    MESSAGE_GUARD_NATIVE_1='.method private static native jrthH([I)V'
    MESSAGE_GUARD_NATIVE_1_REPL='.method private static jrthH([I)V\nreturn-void'
    python3 -c "
orig = open('$PROTECTED_APP_SMALI').read()
a = '$MESSAGE_GUARD_INVOCATION_1'
b = '$MESSAGE_GUARD_INVOCATION_2'
c = '$MESSAGE_GUARD_INVOCATION_3'
d = '$MESSAGE_GUARD_THROW'
native1 = '$MESSAGE_GUARD_NATIVE_1'
native1_repl = '$MESSAGE_GUARD_NATIVE_1_REPL'
if a in orig and b in orig and c in orig and d in orig:
    orig = orig.replace(a, '')
    orig = orig.replace(b, '')
    orig = orig.replace(c, '')
    orig = orig.replace(d, 'return-void')
    orig = orig.replace(native1, native1_repl)
    print('Removed '+a)
    print('Removed '+b)
    print('Removed '+c)
    print('Replaced '+c)

    open('$PROTECTED_APP_SMALI', 'w').write(orig)
else:
    print('Could not find required strings in $PROTECTED_APP_SMALI -- it may have already been patched.')
"
fi

# APK version 1.2 no longer signs in. Remove certificate verification from Volley.newRequestQueue
if [[ "$APK_VERSION" == "$APK_VERSION_1_2" ]]; then
    VOLLEY_BEFORE='invoke-static {v0, v2}, Lcom/android/volley/toolbox/Volley;->newRequestQueue(Landroid/content/Context;Lcom/android/volley/toolbox/BaseHttpStack;)Lcom/android/volley/RequestQueue;'
    VOLLEY_AFTER='invoke-static {v0}, Lcom/android/volley/toolbox/Volley;->newRequestQueue(Landroid/content/Context;)Lcom/android/volley/RequestQueue;'

    NETWORK_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/network/a.smali
    python3 -c "
orig = open('$NETWORK_SMALI').read()
before = '$VOLLEY_BEFORE'
after = '$VOLLEY_AFTER'

if before in orig:
    orig = orig.replace(before, after)
    print('Patched Volley.newRequestQueue')

    open('$NETWORK_SMALI', 'w').write(orig)
else:
    print('Could not find required strings in $NETWORK_SMALI -- it may have already been patched.')
"

fi

if [[ "$PATCH_BT_LOGGING" == "y" ]]; then
    if [[ "$APK_VERSION" == "$APK_VERSION_1_2" ]]; then

        echo "Adding Bluetooth read logging"

        BT_LOGGING_READ_BEFORE='invoke-virtual {v1, v2}, Lcom/tandemdiabetes/ble/i/h;->a([B)V'
        BT_LOGGING_READ_CHECKSTRING='const-string v4, "BLEREAD"'
        BT_LOGGING_READ_ADDED='invoke-static {v2}, Lorg/apache/commons/codec/binary/Hex;->encodeHexString([B)Ljava/lang/String;
    move-result-object v5
    const-string v4, "BLEREAD"
    invoke-static {v4, v5}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I'
        CONTROLLER_READ_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/ble/daemon/'Controller$f.smali'

        python3 -c "
orig = open('$CONTROLLER_READ_SMALI').read()
before = '$BT_LOGGING_READ_BEFORE'
checkstring = '$BT_LOGGING_READ_CHECKSTRING'
after = '''$BT_LOGGING_READ_BEFORE
$BT_LOGGING_READ_ADDED'''

if before in orig and not checkstring in orig:
    orig = orig.replace(before, after)
    print('Added BT read logging')

    open('$CONTROLLER_READ_SMALI', 'w').write(orig)
else:
    print('Could not find required strings in $CONTROLLER_READ_SMALI -- it may have already been patched.')
"
        echo "Adding Bluetooth write logging"

        BT_LOGGING_WRITE_BEFORE='invoke-virtual {p0, v0}, Lcom/tandemdiabetes/ble/daemon/Controller;->a(Lcom/tandemdiabetes/ble/daemon/g;)V'
        BT_LOGGING_WRITE_CHECKSTRING='const-string v3, "BLEWRITE"'
        BT_LOGGING_WRITE_ADDED='invoke-static {p1}, Lorg/apache/commons/codec/binary/Hex;->encodeHexString([B)Ljava/lang/String;
    move-result-object v4
    const-string v3, "BLEWRITE"
    invoke-static {v3, v4}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I'
        CONTROLLER_WRITE_SMALI=$EXTRACT_FOLDER/smali/com/tandemdiabetes/ble/daemon/Controller.smali

        python3 -c "
orig = open('$CONTROLLER_WRITE_SMALI').read()
before = '$BT_LOGGING_WRITE_BEFORE'
checkstring = '$BT_LOGGING_WRITE_CHECKSTRING'
after = '''$BT_LOGGING_WRITE_ADDED
$BT_LOGGING_WRITE_BEFORE
'''

if before in orig and not checkstring in orig:
    orig = orig.replace(before, after)
    print('Added BT write logging')

    open('$CONTROLLER_WRITE_SMALI', 'w').write(orig)
else:
    print('Could not find required strings in $CONTROLLER_WRITE_SMALI -- it may have already been patched.')
"

    fi
fi


echo "Done patching source files. You can make any other modifications now."
echo ""
read -p "<!> Continue to generate patched APK? [Y/n] " CONTINUE
if [[ "$CONTINUE" == "y" || "$CONTINUE" == "Y" || "$CONTINUE" == "" ]]; then
    echo "Okay. continuing."
else
    exit -1;
fi

echo "Generating patched APK $PATCHED_APK"
apktool b --use-aapt2 -o "$PATCHED_APK" "$EXTRACT_FOLDER"

if [[ ! -f "$PATCHED_APK" ]]; then
    echo "ERROR: apktool failed to generate a patched APK."
    echo "Check the error output above."
    exit -1
fi

KEYSTORE=debug.keystore

if [ ! -f "$KEYSTORE" ]; then
    echo "Generating debug keystore at $KEYSTORE"
    echo "<!> When prompted, enter any password. You will be prompted to re-enter it when signing the APK."
    echo "<!> For simplicity, you can input the word 'password'"
    echo "<!> All non-password fields are optional. Type 'yes' when asked if your input was correct."

    keytool -genkey -v -keystore "$KEYSTORE" -alias alias_name -keyalg RSA -keysize 2048 -validity 10000
else
    echo "<!> Existing debug keystore found. Please enter your existing keystore password (e.g. 'password')"
fi

echo "Signing patched APK..."
echo "<!> When prompted, enter the password for $KEYSTORE"
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore "$KEYSTORE" "$PATCHED_APK" alias_name

echo "Done! You can now install $PATCHED_APK on your device."
echo ""
echo "IMPORTANT: If you currently have a release version of the t:connect app installed,"
echo "you MUST uninstall it before installing the patched version. This tool will attempt"
echo "to do so automatically."
echo ""
echo "Please plug in your Android device and enable USB debugging in settings."
echo ""
read -p "<!> Would you like to install the patched APK now? [y/N] " INSTALL_NOW
if [[ "$INSTALL_NOW" == "y" || "$INSTALL_NOW" == "Y" ]]; then
    echo "Okay, running adb install"
    if [[ "$(which python3)" == "" ]]; then
        echo "ERROR: You do not have adb installed, so cannot install the APK directly." 1>&2;
        echo "You can upload the apk file to your phone and install it manually." 1>&2;
    else
        tmpfile=$(mktemp)
        (adb shell dumpsys package "$EXPECTED_PACKAGE" 2>&1 | grep 'pkgFlags=') | tee $tmpfile
        if grep -q "DEBUGGABLE" $tmpfile; then
            echo "A patched t:connect application is already installed."
        else
            echo "<!> You have a non-patched version of t:connect application already installed."
            read -p "<!> Can it be uninstalled now? [Y/n]" UNINSTALL
            if [[ "$UNINSTALL" == "y" || "$UNINSTALL" == "Y" ]]; then
                adb uninstall com.tandemdiabetes.tconnect
                echo "OK, continuing to install patched APK"
            else
                echo "Warning, the application may not properly install"
            fi
        fi

        tmpfile=$(mktemp)
        (adb install $PATCHED_APK 2>&1 ) | tee $tmpfile
        if grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE" $tmpfile; then
            read -p "<!> The package was not installed. Would you like to delete the existing t:connect application and reinstall? [Y/n]" REINSTALL
            if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
                adb uninstall com.tandemdiabetes.tconnect
                echo "Retrying install..."
                adb install $PATCHED_APK
            else
                exit 1
            fi
        fi

        echo "All set!"
    fi
fi

echo ""
echo "You'll need to re-login to the app, and also un-pair and re-pair your pump to your phone."
echo "Thanks for using this tool!"
