import frida, sys

def on_message(message, data):
    if message['type'] == 'send':
        print("[*] {0}".format(message['payload']))
    else:
        print(message)

jscode = """
var do_dlopen = null;
var call_ctor = null;
var packagename = "com.our.target.apk"
var Check;
Process.findModuleByName('linker64').enumerateSymbols().forEach(function(sym) {
    if (sym.name.indexOf('do_dlopen') >= 0) {
        do_dlopen = sym.address;
    } else if (sym.name.indexOf('call_constructor') >= 0) {
        call_ctor = sym.address;
    }
})
Interceptor.attach(do_dlopen, function() {
    var library = this.context['x0'].readUtf8String();
    console.log(library);
    if (library != null) {
        if (library.indexOf(packagename) >= 0 && library.indexOf("base.odex") >= 0) {
            console.log("[*] Odex Loading : " + library);
            Check = library.replace("oat/arm64/base.odex", "lib/arm64/libbaseapk.so");
            Hook(Check)
        }
    }
})

function Hook(Input) {
    var OriginalSign = "3082........";
    Java.performNow(function() {
        try {
            var Context = Java.use('android.app.ContextImpl');
            Context.getPackageCodePath.overload().implementation = function() {
                return Input;
            }
            Context.getPackageResourcePath.overload().implementation = function() {
                return Input;
            }
            Context.getApplicationInfo.overload().implementation = function() {
                var ret = this.getApplicationInfo();
                console.log("android.app.ContextImpl;->getApplicationInfo called");
                ret.sourceDir.value = Input;
                ret.publicSourceDir.value = Input;
                return ret;
            }

            function TBA() {
                var output = Java.array('byte', HTB(OriginalSign));
                return output;
            }

            function TCA() {
                var ArraySignChar = Array.from(OriginalSign);
                return ArraySignChar;
            }

            function HTB(hex) {
                for (var bytes = [], c = 0; c < hex.length; c += 2) bytes.push(parseInt(hex.substr(c, 2), 16));
                return bytes;
            }
            var Verf = Java.use("java.security.Signature");
            Verf.verify.overload("[B").implementation = function(by) {
                return true;
            }
            var Stub = Java.use("android.content.pm.IPackageManager$Stub$Proxy");
            Stub.getApplicationInfo.overload("java.lang.String", "int", "int").implementation = function(pkgname, flag, flag2) {
                var ret = this.getApplicationInfo.call(this, pkgname, flag, flag2);
                if (pkgname == packagename) {
                    console.log("android.content.pm.IPackageManager$Stub$Proxy;->getApplicationInfo(sourceDir) called");
                    ret.sourceDir.value = Input;
                    ret.publicSourceDir.value = Input;
                }
                return ret;
            }
            var PackageManager = Java.use("android.app.ApplicationPackageManager");
            PackageManager.getApplicationInfo.implementation = function(pn, flags) {
                var ret = this.getApplicationInfo(pn, flags);
                if (pn === pkg) {
                    ret.sourceDir.value = Input;
                    ret.publicSourceDir.value = Input;
                    console.log("android.app.ApplicationPackageManager;->(sourceDir) Hooked");
                }
                return ret;
            }
            var ACPSign = Java.use("android.content.pm.Signature");
            ACPSign["toByteArray"].overload().implementation = function() {
                console.log("android.content.pm.Signature;->toByteArray called");
                var Fix = TBA();
                return Fix;
            };
            ACPSign["hashCode"].overload().implementation = function() {
                var ret = this["hashCode"]();
                console.log("Hash : ", ret);
                // return 189889969; This we need to grab from original apk first 
                return ret
            }
            ACPSign["toCharsString"].overload().implementation = function() {
                console.log("android.content.pm.Signature;->toCharsString called");
                return OriginalSign;
            }
            ACPSign["toChars"].overload().implementation = function() {
                console.log("android.content.pm.Signature;->toChars called");
                var Fix = TCA();
                return Fix;
            }
            ACPSign["toChars"].overload("[C", "[I").implementation = function(ch, into) {
                console.log("android.content.pm.Signature;->toChars 2nd called");
                var Fix = TCA();
                return Fix;
            }
        } catch (e) {
            console.error("Error Trigger : ", e);
        }
    })
}
if (Java.available) {
    Java.perform(function() {
        const ActivityThread = Java.use('android.app.ActivityThread');
        const PackageInfo = Java.use('android.content.pm.PackageInfo');
        const ApplicationInfo = Java.use('android.content.pm.ApplicationInfo');
        var context = ActivityThread.currentApplication().getApplicationContext();
        var packageManager = context.getPackageManager();
        var appsinfo = packageManager.getInstalledPackages(0);
        for (var i = 0; i < appsinfo.size(); i++) {
            var app = Java.cast(appsinfo.get(i), PackageInfo);
            if (app.packageName.value == packagename ) {
                app.applicationInfo.value.sourceDir.value = Check;
                console.log("sourceDir Hooked : ", app.applicationInfo.value.sourceDir.value);
            }
        }
    });
}
"""

process = frida.get_usb_device().attach('com.tandemdiabetes.tconnect')
script = process.create_script(jscode)
script.on('message', on_message)
print('[*] Running CTF')
script.load()
sys.stdin.read()