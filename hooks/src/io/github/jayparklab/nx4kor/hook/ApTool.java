package io.github.jayparklab.nx4kor.hook;

import java.lang.reflect.Method;

/**
 * The projection AP (apMode 2) off and on again through Android's own Wi-Fi service, for the
 * USB Wi-Fi dongle (#48, #80): after the stock unit cuts the USB port's power once (about 40 s
 * into a boot with the dongle in), the dongle comes back as a new wlan0 while Android still says
 * the AP is on and HMG-API's keeper wrote it up for this boot (HMG-API #386). svc/dongle.sh runs
 * this as root, once, only then:
 *   CLASSPATH=<mod>/hooks.jar app_process /system/bin io.github.jayparklab.nx4kor.hook.ApTool restart
 * Off: the stock Wi-Fi service stops hostapd and unloads bcmdhd; on: it loads bcmdhd again (the
 * dongle driver bound on the stock slot) and starts hostapd. The same IWifiManager calls as
 * HMG-API's WifiAp (rc.10), our own copy so an HMG-API update can't change them under us.
 * The car's own Wi-Fi client (home Wi-Fi while parked) has the radio, or Android will restore it: left alone.
 * Not loaded by HMG-API (only Nx4KorHooks is the entry); it rides in hooks.jar to be one dex.
 */
public final class ApTool {
    private ApTool() {}

    static final int AP_DISABLED = 11, AP_ENABLING = 12, AP_ENABLED = 13;
    static final int CLIENT_ENABLING = 2, CLIENT_ENABLED = 3;

    public static void main(String[] args) throws Exception {
        if (args.length != 1 || !"restart".equals(args[0])) {
            System.out.println("usage: ApTool restart");
            System.exit(2);
        }
        Object b = Class.forName("android.os.ServiceManager").getMethod("getService", String.class).invoke(null, "wifi");
        if (b == null) {
            System.out.println("no Wi-Fi service");
            System.exit(1);
        }
        Class<?> i = Class.forName("android.net.wifi.IWifiManager");
        Object wifi = Class.forName("android.net.wifi.IWifiManager$Stub")
                .getMethod("asInterface", Class.forName("android.os.IBinder")).invoke(null, b);
        Class<?> conf = Class.forName("android.net.wifi.WifiConfiguration");
        Method apState = i.getMethod("getWifiApEnabledState");
        Method clientState = i.getMethod("getWifiEnabledState");
        Method set = i.getMethod("setWifiApEnabledForConnectivity", conf, boolean.class);
        int client = (Integer) clientState.invoke(wifi);
        if (client == CLIENT_ENABLED || client == CLIENT_ENABLING || clientSavedOn(i, wifi)) {
            System.out.println("the car's own Wi-Fi client is on or set to restore, left alone");
            System.exit(0);
        }
        int ap = (Integer) apState.invoke(wifi);
        if (ap == AP_ENABLED || ap == AP_ENABLING) {
            set.invoke(wifi, null, false);
            for (int t = 0; t < 40 && (Integer) apState.invoke(wifi) != AP_DISABLED; t++) Thread.sleep(250);
        }
        set.invoke(wifi, null, true);
        for (int t = 0; t < 60 && (Integer) apState.invoke(wifi) != AP_ENABLED; t++) Thread.sleep(250);
        int now = (Integer) apState.invoke(wifi);
        System.out.println("projection AP " + (now == AP_ENABLED ? "on" : "didn't come on (state " + now + ")")
                + " (it was " + ap + ")");
        System.exit(now == AP_ENABLED ? 0 : 1);
    }

    /** Android will turn the car's client back on (vendor getPersistedWifiEnabled, as HMG-API's WifiAp checks); absent on some builds. */
    static boolean clientSavedOn(Class<?> type, Object wifi) throws ReflectiveOperationException {
        try {
            return Boolean.TRUE.equals(type.getMethod("getPersistedWifiEnabled").invoke(wifi));
        } catch (NoSuchMethodException e) {
            return false;
        }
    }
}
