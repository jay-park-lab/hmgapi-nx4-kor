package io.github.jayparklab.nx4kor.hook.dipo;
// NX4 KOR (jay-park-lab/hmgapi-nx4-kor), 2026-11-25 (#67). The route guidance listener, its thread,
// the 1-second refresh and the Stop/Start restart follow the official Wireless CarPlay + Android Auto
// mod's Dipo.java (Open-HMG/hmgapi-wireless-cp-aa v2.2.0-rc.9, VysseCodes, AGPL-3.0) and Korea
// Projection's (StopDragon/HMG-API korea-build 6258357, AGPL-3.0). The cluster override is NX4 KOR's.

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.SystemClock;

import com.tcc.iap2.IIap2Listener;
import com.tcc.iap2.IIap2Service;
import com.tcc.iap2.Iap2ListenerInfo;
import com.tcc.iap2.Iap2NotiMsg;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import hmgapi.hook.Car;
import hmgapi.hook.Cluster;
import hmgapi.hook.LoadedApp;
import hmgapi.hook.MethodHook;
import hmgapi.hook.ModContext;

/**
 * Korean CarPlay turn-by-turn in DiPO, beside the official mod (whose "tbt" stays on: it still
 * tells the iPhone the car takes route guidance, keeps the car navigation off the cluster and
 * runs Android Auto's turn-by-turn).
 *
 * 1. Its own iAP2 listener for route guidance (type 4096, name NX4KOR_RG) gets the phone's
 *    120/121/122 next to the official mod's, and Korea Projection's CpTurnsFit (with
 *    HMG-Seogaemo's lane glyphs) works out what the cluster and HUD show, on a thread of its own,
 *    resending every second while guidance is on. The official mod stops at a maneuver its
 *    table has no icon for, or whose 121 it missed (#67); CpTurnsFit doesn't.
 * 2. The cluster calls in DiPO (framework.navigation_cluster.*, hooked "change": HMG-API keeps
 *    the official mod's "replace" hooks, which are only in the car navigation, loaded) remember
 *    what this thread sent; while CpTurnsFit has guidance on, a call from any other thread (the
 *    official mod's) gets this thread's last arguments for that call instead, so both senders
 *    show the same. With nothing from this listener (none of ours active), the official mod's
 *    calls pass as they are. If the official mod keeps calling while this listener hears nothing
 *    for 3 s, this mod gives way (its calls pass, ours stop resending) until it hears again.
 * 3. A Stop of the phone's route guidance that isn't this mod's own clears ours 2 s later, unless
 *    the phone sends again meanwhile: the official mod asks again with Stop and Start (a source
 *    change, its watchdog), and only DiPO's own Stop (CarPlay ends) is followed by silence.
 * 4. The mod turned off in the HMG-API app while DiPO runs: its hooks pass (HMG-API), and this
 *    part stops feeding and resending (mod.enabled()), so only the official mod draws.
 * The decisions of 2 and 3 are in TbtGate (the PC tests run them).
 */
public final class KorTbt {
    private KorTbt() {}

    static final String IAP2_ACTION = "com.remote.service.IAP2SERVICE";
    /** iAP2 listener type for route guidance (notifications 120, 121, 122), as the official mod's */
    static final int LISTENER_ROUTE_GUIDANCE = 4096;
    static final String LISTENER_NAME = "NX4KOR_RG";
    static final int RG_UPDATE = 120, RG_MANEUVER = 121, RG_LANES = 122;
    static final String[] RG_COMPONENTS = { "RouteGuidanceComponent0" };
    /** the cluster calls HMG-API's Cluster API makes (all CpTurnsFit sends) */
    static final String[] CLUSTER_POINTS = {
        "update_tbt_info", "update_tbt_sub_info_b", "update_tbt_sub_info_2c", "update_tp_turn_list_new",
        "update_lane_info", "update_tp_destination_name", "update_tp_crossroad_name", "update_tp_turn_list",
    };
    /** after a restart of ours, CpTurnsFit asks again for a maneuver it misses only after this long (as KP) */
    static final long RESTART_QUIET_MS = 10000L;

    static ModContext mod;
    static volatile IIap2Service iap2;
    static HandlerThread thread;
    static Handler handler;
    static CpTurnsFit turns;
    /** what to give the official mod's cluster calls, giving way, the pending Stop (written on the thread and the binder) */
    static final TbtGate gate = new TbtGate();
    /** points whose first override was logged */
    static final Set<String> overrideLogged = Collections.synchronizedSet(new HashSet<String>());
    /** set while this mod itself calls the iAP2 server (its restart), so its own Stop isn't DiPO's */
    static final ThreadLocal<Boolean> OWN = new ThreadLocal<Boolean>();
    static final Object RESTART_LOCK = new Object();
    static volatile long lastRestartAt;
    static volatile boolean heard;
    /** whether REFRESH is scheduled (only touched on the thread) */
    static boolean refreshing;
    static int refreshErrors;
    /** errors from a step on the thread (post), logged up to 3 (#77) */
    static int postErrors;
    /** giving way logged (only touched on the thread) */
    static boolean yieldLogged;
    /** the mod was turned off while guidance was on (REFRESH reset ours): ask the phone for all of it when back on */
    static volatile boolean wasOff;

    static void log(String m) {
        mod.log(m);
    }

    static void error(String m, Throwable t) {
        mod.error(m, t);
    }

    /** Nx4KorHooks.appLoaded (reflection), in DiPO's process */
    public static void start(ModContext m, LoadedApp app) {
        mod = m;
        if (Car.stepOfSpec() >= 999) {
            log("CarPlay (NX4 KOR): stepofspec is 999 or more, DiPO's own turn-by-turn runs (Korean turn-by-turn stays off)");
            return;
        }
        Cluster c = Cluster.of(app.context);
        if (c == null) {
            log("CarPlay (NX4 KOR): no cluster service here (Korean turn-by-turn stays off)");
            return;
        }
        thread = new HandlerThread("nx4kor-cp-tbt");
        thread.start();
        handler = new Handler(thread.getLooper());
        // the cluster through ClusterOut: a call the official mod's call already carried isn't made again (#77)
        turns = new CpTurnsFit(app.context, new ClusterOut(c, gate), new Runnable() {
            @Override
            public void run() {
                // Stop, a moment, Start. CpTurnsFit already runs this on a thread of its own (#77: no second thread)
                restartRouteGuidance();
            }
        });
        turns.debug = m.settingBoolean("kor_tbt_log", true);
        turns.onActive = new Runnable() {
            @Override
            public void run() {
                if (refreshing) return;
                refreshing = true;
                handler.postDelayed(REFRESH, 1000L);
            }
        };
        turns.busy = new CpTurnsFit.Busy() {
            @Override
            public boolean busy() {
                long at = lastRestartAt;
                return at != 0L && SystemClock.elapsedRealtime() - at < RESTART_QUIET_MS;
            }
        };
        // A Stop of the phone's route guidance that isn't ours: DiPO's own (CarPlay ends) or the official
        // mod asking again (Stop, then Start). Clear ours only if the phone stays quiet (TbtGate.stopDue)
        m.hook(app.classLoader, "dipo.iap2_proxy.stop_route_guidance", new MethodHook() {
            @Override
            protected void beforeHookedMethod(Param p) {
                if (OWN.get() != null) return;
                gate.stopSeen(SystemClock.elapsedRealtime());
                Handler h = handler;
                if (h != null) {
                    h.removeCallbacks(STOP_CHECK);   // #77: one check for the latest Stop (stopDue looks at that one)
                    h.postDelayed(STOP_CHECK, TbtGate.STOP_WAIT_MS + 50L);
                }
            }
        });
        for (String point : CLUSTER_POINTS) override(point);
        final Listener listener = new Listener();
        boolean bound = app.context.bindService(new Intent(IAP2_ACTION), new ServiceConnection() {
            @Override
            public void onServiceConnected(ComponentName name, IBinder b) {
                IIap2Service s = IIap2Service.Stub.asInterface(b);
                iap2 = s;
                try {
                    Iap2ListenerInfo info = new Iap2ListenerInfo();
                    info.onSetSupportType(LISTENER_ROUTE_GUIDANCE);
                    info.onSetListenerName(LISTENER_NAME);
                    log("CarPlay (NX4 KOR): Iap2SvcInit(" + LISTENER_NAME + ", 0x1000) = " + s.Iap2SvcInit(listener, info));
                } catch (Throwable t) {
                    error("CarPlay (NX4 KOR): route guidance listener", t);
                }
            }

            @Override
            public void onServiceDisconnected(ComponentName name) {
                iap2 = null;
                log("CarPlay (NX4 KOR): iAP2 server gone");
            }
        }, Context.BIND_AUTO_CREATE);
        log("CarPlay (NX4 KOR): Korean turn-by-turn (Korea Projection's fit) beside the official mod; iAP2 server "
                + (bound ? "binding" : "can't be bound"));
    }

    /** a cluster call: remember ours, give the official mod's ours (TbtGate.forOther) */
    static void override(final String point) {
        mod.hook(null, "framework.navigation_cluster." + point, new MethodHook() {
            @Override
            protected void beforeHookedMethod(Param p) {
                if (Thread.currentThread() == thread) {
                    gate.ours(point, p.args);
                    return;
                }
                Object[] c = gate.forOther(point, p.args.length, SystemClock.elapsedRealtime(), mod.enabled());
                if (c == null) return;
                System.arraycopy(c, 0, p.args, 0, c.length);
                if (overrideLogged.add(point)) {
                    log("CarPlay (NX4 KOR): " + point + " from the official mod replaced with ours (logged once per call)");
                }
            }
        });
    }

    /** runs r on the thread, then notes whether guidance is on (and forgets our calls when it goes off) */
    static void post(final Runnable r) {
        Handler h = handler;
        if (h == null) return;
        h.post(new Runnable() {
            @Override
            public void run() {
                try {
                    r.run();
                } catch (Throwable x) {
                    // #77: the first few only (one failing every update would fill the log with stacks)
                    if (postErrors++ < 3) error("CarPlay (NX4 KOR) turn-by-turn", x);
                }
                noteActive();
            }
        });
    }

    static void noteActive() {
        int t = gate.setActive(turns.active());
        if (t < 0) log("CarPlay (NX4 KOR): guidance off: the official mod's cluster calls pass again");
        else if (t > 0) log("CarPlay (NX4 KOR): guidance on: the official mod's cluster calls get ours");
    }

    /** resend about every second while guidance is on; not while the mod is off or gives way (TbtGate.yielding) */
    static final Runnable REFRESH = new Runnable() {
        @Override
        public void run() {
            if (!mod.enabled()) {
                // turned off in the HMG-API app: forget ours, and that it drew anything (nothing cleared now or
                // later: the official mod draws). Turned on again, the first update asks the phone for all of it
                // (Listener.notify), since an update without the state would read as "guidance over"
                turns.reset();
                turns.shown = false;
                turns.hudShown = false;
                wasOff = true;
                noteActive();
                refreshing = false;
                log("CarPlay (NX4 KOR): mod turned off: Korean turn-by-turn stopped, the official mod's alone");
                return;
            }
            long now = SystemClock.elapsedRealtime();
            boolean yielding = gate.yielding(now);
            if (yielding && !yieldLogged) {
                yieldLogged = true;
                log("CarPlay (NX4 KOR): this listener hears nothing while the official mod sends: giving way until it hears again");
            } else if (!yielding) {
                yieldLogged = false;
            }
            if (!yielding) {
                try {
                    turns.refresh();
                } catch (Throwable x) {
                    if (refreshErrors++ < 3) error("CarPlay (NX4 KOR) turn-by-turn refresh", x);
                }
            }
            noteActive();
            // #77: while giving way, nothing to resend: look again when the way ends (the official mod quiet for
            // QUIET_MS; its calls move that on), not every second. Hearing again needs no tick (the update itself sends)
            if (turns.active()) handler.postDelayed(this, yielding ? Math.max(1000L, gate.yieldEndsIn(now)) : 1000L);
            else refreshing = false;
        }
    };

    /** a Stop that wasn't ours, STOP_WAIT_MS later: clear ours if the phone stayed quiet */
    static final Runnable STOP_CHECK = new Runnable() {
        @Override
        public void run() {
            if (!gate.stopDue(SystemClock.elapsedRealtime())) return;
            try {
                turns.stop();
            } catch (Throwable x) {
                error("CarPlay (NX4 KOR) turn-by-turn stop", x);
            }
            noteActive();
        }
    };

    /** Stop, then Start, so the phone sends its whole current state (as the official mod and KP) */
    static void restartRouteGuidance() {
        IIap2Service s = iap2;
        if (s == null) return;
        lastRestartAt = SystemClock.elapsedRealtime();
        synchronized (RESTART_LOCK) {
            OWN.set(Boolean.TRUE);
            try {
                s.Iap2SvcStopRouteGuidanceUpdate(RG_COMPONENTS);
                Thread.sleep(200);
                s.Iap2SvcStartRouteGuidanceUpdate(RG_COMPONENTS, true, true);
            } catch (Throwable t) {
                // the session went away meanwhile
            } finally {
                OWN.remove();
            }
        }
    }

    /** this mod's iAP2 listener for route guidance: everything goes to CpTurnsFit on its thread */
    static final class Listener extends IIap2Listener.Stub {
        @Override
        public void connected(int component, String serial) {}

        @Override
        public void disconnected(int component) {
            // as the official mod's listener: component 2 isn't a session.
            // (The official mod also skips its wireless bridge's own sessions; this mod can't see those.)
            if (component == 2) return;
            post(new Runnable() {
                @Override
                public void run() {
                    turns.disconnected();
                }
            });
        }

        @Override
        public void notify(final int what, int a1, int a2, final Iap2NotiMsg msg) {
            if ((what != RG_UPDATE && what != RG_MANEUVER && what != RG_LANES) || msg == null) return;
            // turned off in the HMG-API app: the official mod's turn-by-turn alone (its calls already pass).
            // What's missed meanwhile is asked for again when it's back on
            if (!mod.enabled()) {
                wasOff = true;
                return;
            }
            gate.heard(SystemClock.elapsedRealtime());
            if (wasOff) {
                // back on: what's left was reset, so have the phone send its whole state (Stop, Start: ours, OWN)
                wasOff = false;
                log("CarPlay (NX4 KOR): mod turned on again: route guidance asked again");
                new Thread(new Runnable() {
                    @Override
                    public void run() {
                        restartRouteGuidance();
                    }
                }, "nx4kor-cp-rg").start();
            }
            if (!heard) {
                heard = true;
                log("CarPlay (NX4 KOR): route guidance reaches this listener (first " + what + ")");
            }
            post(new Runnable() {
                @Override
                public void run() {
                    if (what == RG_UPDATE) turns.routeGuidance(msg);
                    else if (what == RG_MANEUVER) turns.maneuver(msg);
                    else turns.lanes(msg);
                }
            });
        }
    }
}
