// From Open-HMG/hmgapi-wireless-cp-aa v2.2.0-rc.9 (VysseCodes, AGPL-3.0), wireless-carplay-aa/stubs/com/tcc/iap2/IIap2Listener.java, unchanged.
// Compile-time signature of DiPO's iAP2 client library: never in hooks.jar (the car's own class loads from DiPO).
package com.tcc.iap2;

import android.os.IBinder;
import android.os.IInterface;
import android.os.RemoteException;

public interface IIap2Listener extends IInterface {
    void connected(int component, String serial) throws RemoteException;

    void disconnected(int component) throws RemoteException;

    void notify(int what, int arg1, int arg2, Iap2NotiMsg msg) throws RemoteException;

    abstract class Stub extends android.os.Binder implements IIap2Listener {
        public Stub() {}

        public IBinder asBinder() {
            return this;
        }
    }
}
