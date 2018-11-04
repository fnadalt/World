
class Dummy : ScriptObject
{
    float Number = 1.0f;

    void DelayedStart()
    {
        Component@[]@ cs = node.GetComponents();
        int n = cs.length;
        log.Info("Number of components: " + n);

        for (int i = 0; i < n; i++) {
            Component@ c = cs[i];
            log.Info("component: " + c.typeName);
        }

        ScriptObject@ so = node.GetScriptObject("Dummy");
        if (so is null) {
            log.Error("ScriptObject null");
        } else {
            log.Info("ScriptObject found");
            Dummy@ dummy = cast<Dummy>(so);
            log.Info("Number=" + dummy.Number);
        }
    }

    void Delayed()
    {
    }

}
