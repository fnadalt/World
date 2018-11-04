
class SunRig : ScriptObject
{

    Node@ sunNode;
    Light@ sunLight;

    void DelayedStart()
    {
        log.Info("SunRig::Start");
        //
        sunNode = node.GetChild("Sun");
        sunLight = cast<Light>(sunNode.GetComponent("Light"));
        //
        SubscribeToEvent("KeyUp", "HandleKeyUp");
    }

    void Stop()
    {
        log.Info("SunRig::Stop");
        UnsubscribeFromEvent("KeyUp");
        //
        sunNode = null;
        sunLight = null;
    }

    void Update(float timeStep)
    {
        if (sunNode.worldPosition.y < 0.0f && sunLight.enabled == true)
        {
            sunLight.enabled = false;
        }
        else if (sunNode.worldPosition.y > 0.0f && sunLight.enabled == false)
        {
            sunLight.enabled = true;
        }
        //~ debugHud.SetAppStats("Sun height", sunNode.position.ToString());
    }

    void HandleKeyUp(StringHash eventType, VariantMap& eventData)
    {
        int key = eventData["Key"].GetInt();
        if (key == KEY_PLUS)
            node.Roll(5);
        else if (key == KEY_MINUS)
            node.Roll(-5);
    }

}
