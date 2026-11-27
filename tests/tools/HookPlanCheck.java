import hmgapi.engine.HookPlan;
import hmgapi.engine.Json;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * tests/mod-test.sh (#67): HMG-API's own hook plan (the rules the zygote's mod loader and the
 * engine's plan use) for nx4-kor beside the official mod, on the NX4 map.
 *   java -cp <engine classes>:. HookPlanCheck <nx4-kor mod.json> <official hooks fixture> <map points file>
 * Prints the load order, refusals and shared points (HookPlan.report), then "ok" when both
 * mods load and no point is refused.
 */
public class HookPlanCheck {
    static String read(String f) throws Exception {
        return new String(Files.readAllBytes(new File(f).toPath()), StandardCharsets.UTF_8);
    }

    public static void main(String[] a) throws Exception {
        Map<String, Map<String, Object>> mods = new LinkedHashMap<String, Map<String, Object>>();
        Map<String, Object> ours = Json.object(read(a[0]));
        Map<String, Object> wm = Json.object(read(a[1]));
        mods.put(String.valueOf(ours.get("id")), ours);
        mods.put(String.valueOf(wm.get("id")), wm);
        Set<String> known = new HashSet<String>();
        for (String l : read(a[2]).split("\n")) {
            l = l.trim();
            if (l.length() > 0 && !l.startsWith("#")) known.add(l);
        }
        HookPlan p = HookPlan.of(mods, known);
        System.out.println("order " + p.order);
        List<String> r = p.report();
        for (String l : r) System.out.println(l);
        boolean ok = p.refused.isEmpty() && p.order.contains(ours.get("id")) && p.order.contains(wm.get("id"));
        System.out.println(ok ? "ok" : "refused " + p.refused);
        System.exit(ok ? 0 : 1);
    }
}
