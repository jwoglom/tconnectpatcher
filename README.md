# tconnectpatcher

**December 2021 Update:** tconnectpatcher is now able to work around a Tandem bug which prevented v1.2 of the app from launching.
Since tconnectpatcher has only supported app version 1.2, this allows quicker uploads in the t:connect app to be performed again.

## Prerequisites

Tconnectpatcher patches the t:connect Android app to upload data via their API more frequently.
It is written in bash, and should work on any Linux/Unix/MacOS system.
In order to run the tool, you must have Python 3 and [apktool](https://ibotpeaches.github.io/Apktool/install/) installed.

To generate a "patched" APK, a valid APK of the [t:connect Android application](https://play.google.com/store/apps/details?id=com.tandemdiabetes.tconnect) must be provided.
Currently only version 1.2, released in September 2020, is supported.
You can extract this APK from an Android phone which has the application installed from the Play Store, [or find it on the internet](http://google.com/search?q=com.tandemdiabetes.tconnect+1.2+android+apk) via one of the standard APK mirrors.  Make sure to download version 1.2.

Once you have the APK downloaded, open a Terminal and clone and cd into this repository. Or, download the `patch.sh` file (click on the file name and then the 'Raw' button) and cd to the folder where you downloaded that file.

```bash
$ git clone https://github.com/jwoglom/tconnectpatcher
$ cd tconnectpatcher
$ ./patch.sh path/to/downloaded.apk
```
Then run `./patch.sh path/to/downloaded.apk`, where `path/to/downloaded.apk` is the path of the file you extraced or downloaded. (Hint: You can drag the .apk file into the Terminal window to get the full path.) Alternatively, move the downloaded APK into the same `tconnectpatcher` directory as the `patch.sh` file, and then run `./patch.sh ./downloaded.apk`, replacing `downloaded.apk` with the name of the file.

You'll be asked:

* **How often (in minutes) should t:connect upload data to the cloud?** If you'd like to upload your pump data more frequently to the cloud, set this to, e.g., `5` or `15`

From there, follow the steps to create a local debug keystore, build the APK, and then install it on your phone.

## Advanced Usage

To modify these options, run the tool with `./patch.sh path/to/downloaded.apk --advanced`

You'll be prompted about several options:

* **Would you like to make the APK debuggable?** This makes the Android app [debuggable](https://developer.android.com/guide/topics/manifest/application-element#debug). Defaults to yes.
* **Would you like to disable certificate verification?** If set, this allows you to look at outgoing HTTPS connections made by the app. Defaults to yes.
* **How often (in minutes) should t:connect upload data to the cloud?** If you'd like to upload your pump data more frequently to the cloud, set this to, e.g., `5` or `15`
* **Modify to log bluetooth data?** If set, all bluetooth reads and writes are logged to `adb logcat` with tags `BLEREAD` and `BLEWRITE`. For use in logging phone-pump Bluetooth communication. Defaults to true.

## Example

Here is an example invocation of the tool:

```
$ ./patch.sh tconnect_mobile_v1.2.apk
   t:connect Patcher: version 1.2
 github.com/jwoglom/tconnectpatcher
------------------------------------

This is a patcher utility which adds additional configuration
options to the Tandem Diabetes t:connect Android app.

Currently only version 1.2 is supported.

Input APK: tconnect_mobile_v1.2.apk

-------------------- PATCH OPTIONS --------------------
<!> Would you like to make the APK debuggable? [Y/n] y
Okay, making the APK debuggable.

<!> Would you like to disable certificate verification? [y/N] n
Not updating the APK security configuration.

<!> How often (in minutes) should t:connect upload data to the cloud? [default: 60] 5
Okay, will change the data upload rate to 5 minutes

Beginning patch...
Extracting APK to extract_tconnect_mobile_v1.2
I: Using Apktool 2.4.1 on tconnect_mobile_v1.2.apk
I: Loading resource table...
I: Decoding AndroidManifest.xml with resources...
I: Loading resource table from file: /Users/james/Library/apktool/framework/1.apk
I: Regular manifest package...
I: Decoding file-resources...
I: Decoding values */* XMLs...
I: Baksmaling classes.dex...
I: Baksmaling classes2.dex...
I: Copying assets and libs...
I: Copying unknown files...
I: Copying original files...
I: Copying META-INF/services directory
Package ID matches
Applying APK modifications...
Applying AndroidManifest patches
Applying patches: 'android:extractNativeLibs': 'true', 'android:allowBackup': 'true', 'android:debuggable': 'true',
Patching application tag in extract_tconnect_mobile_v1.2/AndroidManifest.xml
Deleting field for replacement: {http://schemas.android.com/apk/res/android}extractNativeLibs
Deleting field for replacement: {http://schemas.android.com/apk/res/android}allowBackup
Applying data upload rate patch
Replaced 0x36ee80 with 0x493e0
Done patching source files. You can make any other modifications now.

<!> Continue to generate debug APK? [Y/n] y
Okay. continuing.
Generating debug APK tconnect_mobile_v1.2-debug.apk
I: Using Apktool 2.4.1
I: Checking whether sources has changed...
I: Smaling smali folder into classes.dex...
I: Checking whether sources has changed...
I: Smaling smali_classes2 folder into classes2.dex...
I: Checking whether resources has changed...
I: Building resources...
[ .. ]
I: Built apk...
Generating debug keystore at debug.keystore
<!> When prompted, enter any password. You will be prompted to re-enter it when signing the APK.
<!> All non-password fields are optional. Type 'yes' when asked if your input was correct.
Enter keystore password:
Re-enter new password:
What is your first and last name?
  [Unknown]:
What is the name of your organizational unit?
  [Unknown]:
What is the name of your organization?
  [Unknown]:
What is the name of your City or Locality?
  [Unknown]:
What is the name of your State or Province?
  [Unknown]:
What is the two-letter country code for this unit?
  [Unknown]:
Is CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown correct?
  [no]:  yes

Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 10,000 days
	for: CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown
[Storing debug.keystore]
Signing debug APK...
<!> When prompted, enter the password for debug.keystore
Enter Passphrase for keystore:
[ .. ]
jar signed.

Warning:
The signer's certificate is self-signed.
No -tsa or -tsacert is provided and this jar is not timestamped. Without a timestamp, users may not be able to validate this jar after the signer certificate's expiration date (2048-07-31).
Done! You can now install tconnect_mobile_v1.2-debug.apk on your device.

IMPORTANT: If you currently have a release version of the t:connect app installed,
you MUST uninstall it before installing the patched version.

<!> Would you like to install the patched APK now? [y/N] n
You'll need to re-login to the app, and also un-pair and re-pair your pump to your phone.
Thanks for using this tool!
```

After running the tool, you can install the APK on your Android device using `adb install <new_apk>.apk`.
