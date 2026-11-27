package hmgapi.hook;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/hmgapi/hook/ModEntry.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96).

/** PC 시험용 가짜 ModEntry */
public abstract class ModEntry {
    public void zygoteInit(ModContext mod) throws Throwable {}

    public void appLoaded(ModContext mod, LoadedApp app) throws Throwable {}
}
