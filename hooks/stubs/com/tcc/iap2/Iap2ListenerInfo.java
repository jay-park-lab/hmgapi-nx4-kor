// From Open-HMG/hmgapi-wireless-cp-aa v2.2.0-rc.9 (VysseCodes, AGPL-3.0), wireless-carplay-aa/stubs/com/tcc/iap2/Iap2ListenerInfo.java, unchanged.
// Compile-time signature of DiPO's iAP2 client library: never in hooks.jar (the car's own class loads from DiPO).
package com.tcc.iap2;

public class Iap2ListenerInfo {
    int type;
    String name;

    public void onSetSupportType(int type) {
        this.type = type;
    }

    public void onSetListenerName(String name) {
        this.name = name;
    }
}
