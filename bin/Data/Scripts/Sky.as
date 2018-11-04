
class Sky : ScriptObject
{

    Node@ _sunRig;
    Node@ _sunNode;

    Vector3 SunPositionRel;

    void DelayedStart()
    {
        log.Info("Sky::DelayedStart");
        _sunRig = node.scene.GetChild("SunRig", true);
        _sunNode = node.scene.GetChild("Sun", true);
    }

    void Stop()
    {
        log.Info("Sky::Stop");
        _sunRig = null;
        _sunNode = null;
    }

    void Update(float timeStep)
    {
        SunPositionRel = _sunNode.worldPosition - _sunRig.worldPosition;
        SunPositionRel.Normalize();

        if (debugHud.mode != DEBUGHUD_SHOW_NONE)
            debugHud.SetAppStats("SunPositionRel", SunPositionRel.ToString());

        SetMaterialParams();

    }

    void Load(Deserializer& deserializer)
    {
        SunPositionRel = deserializer.ReadVector3();
        SetMaterialParams();
    }

    void Save(Serializer& serializer)
    {
        serializer.WriteVector3(SunPositionRel);
    }

    void SetMaterialParams()
    {
        Skybox@ skyBox = cast<Skybox>(node.GetComponent("Skybox"));
        Material@ skyboxMat = skyBox.materials[0];
        skyboxMat.shaderParameters["SunPosition"] = Variant(SunPositionRel);
    }

}
