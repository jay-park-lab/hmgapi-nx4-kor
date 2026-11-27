package hmgapi.hook;
// From StopDragon/HMG-API korea-build ebca56f3824a2234e48b336abda927d7a635e243, mods/wireless-carplay-aa/tools/trapbar/stubs/hmgapi/hook/Car.java
// (Korea Projection, AGPL-3.0): a PC test stub for TrapBarTest (#96). Modified by NX4 KOR: carPlayGuiding (TrapBar asks
// only CarPlay, PR #98 review 5), counted in the same phoneGuidingCalls.

/** PC 시험용 가짜 Car: 폰 안내 여부를 시험이 정한다 */
public final class Car {
    public static final int REGION_US = 1, REGION_CANADA = 4;
    public static final int DISTANCE_KM = 0, DISTANCE_MILES = 1;
    public static int unit = DISTANCE_KM;
    public static boolean guiding;
    public static int phoneGuidingCalls;

    public static boolean phoneGuiding(android.content.Context c) {
        phoneGuidingCalls++;
        return guiding;
    }

    public static boolean carPlayGuiding(android.content.Context c) {
        phoneGuidingCalls++;
        return guiding;
    }

    public static int region() { return 0; }

    public static int stepOfSpec() { return 0; }

    public static int distanceUnit(android.content.Context c) { return unit; }
}
