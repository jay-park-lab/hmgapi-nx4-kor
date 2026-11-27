// From Open-HMG/hmgapi-wireless-cp-aa v2.2.0-rc.9 (VysseCodes, AGPL-3.0), wireless-carplay-aa/stubs/com/tcc/iap2/IIap2Service.java, unchanged.
// Compile-time signature of DiPO's iAP2 client library: never in hooks.jar (the car's own class loads from DiPO).
package com.tcc.iap2;

import android.os.IBinder;
import android.os.IInterface;
import android.os.RemoteException;

public interface IIap2Service extends IInterface {
    boolean Iap2SvcInit(IIap2Listener listener, Iap2ListenerInfo info) throws RemoteException;

    boolean Iap2SvcStartRouteGuidanceUpdate(String[] components, boolean a, boolean b) throws RemoteException;

    boolean Iap2SvcStopRouteGuidanceUpdate(String[] components) throws RemoteException;

    boolean Iap2SvcTransportReadDone(byte[] data, int length) throws RemoteException;

    boolean Iap2SvcNowPlayingStart() throws RemoteException;

    boolean Iap2SvcNowPlayingStop() throws RemoteException;

    abstract class Stub extends android.os.Binder implements IIap2Service {
        public static IIap2Service asInterface(IBinder b) {
            throw new UnsupportedOperationException("stub");
        }
    }
}
