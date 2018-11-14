#include "States.as"

class StateStart : State
{

    UIElement@ uiStart;

    StateStart()
    {
        super("Start", APP_STATE_START);
    }

    void Enter(State& prevState, VariantMap& data = VariantMap())
    {
        State::Enter(prevState, data);
        SetupUI(true);
        SetupScene(true);
        SubscribeToEvent("KeyDown", "HandleKeyDown");
    }

    void Exit()
    {
        State::Exit();
        SetupScene(false);
        SetupUI(false);
        UnsubscribeFromEvent("KeyDown");
    }

    void SetupUI(bool flag)
    {
        if (flag)
        {
            XMLFile@ uiFileStart = cache.GetResource("XMLFile", "UI/Start.xml");
            uiStart = ui.LoadLayout(uiFileStart);
            ui.root.AddChild(uiStart);
            Button@ exitButton = uiStart.GetChild("btnExit", true);
            Button@ wlocalButton = uiStart.GetChild("btnWorldLocal", true);
            Button@ wnetButton = uiStart.GetChild("btnWorldNetwork", true);
            Button@ wsrvButton = uiStart.GetChild("btnWorldServer", true);
            Button@ terrButton = uiStart.GetChild("btnTerrain", true);
            SubscribeToEvent(exitButton, "Released", "HandleExitClicked");
            SubscribeToEvent(wlocalButton, "Released", "HandleWLocalClicked");
            SubscribeToEvent(wnetButton, "Released", "HandleWNetClicked");
            SubscribeToEvent(wsrvButton, "Released", "HandleWSrvClicked");
            SubscribeToEvent(terrButton, "Released", "HandleTerrainClicked");
            //
            log.Info("graphics.size = " + graphics.size.ToString());
            Sprite@ bg = ui.root.GetChild("Background");
            bg.position = Vector2(-graphics.size.x, -graphics.size.y) / 2.0f;
            bg.size = graphics.size;
        } else {
            Button@ exitButton = uiStart.GetChild("btnExit", true);
            Button@ wlocalButton = uiStart.GetChild("btnWorldLocal", true);
            Button@ wnetButton = uiStart.GetChild("btnWorldNetwork", true);
            Button@ wsrvButton = uiStart.GetChild("btnWorldServer", true);
            Button@ terrButton = uiStart.GetChild("btnTerrain", true);
            UnsubscribeFromEvent(exitButton, "Released");
            UnsubscribeFromEvent(wlocalButton, "Released");
            UnsubscribeFromEvent(wnetButton, "Released");
            UnsubscribeFromEvent(wsrvButton, "Released");
            UnsubscribeFromEvent(terrButton, "Released");
            ui.root.RemoveChild(uiStart);
            uiStart = null;
        }
    }

    void SetupScene(bool flag)
    {
        if (flag)
        {
            input.mouseVisible = true;
            //~ scene_.LoadXML(cache.GetFile("Scenes/Start.xml"));
            //~ Node@ camDrv = scene_.GetChild("CameraDriver");
            //~ if (camDrv !is null) {
                //~ cameraNode.position = camDrv.worldPosition;
                //~ cameraNode.rotation = camDrv.worldRotation;
            //~ }
        } else {
            input.mouseVisible = false;
            //~ scene_.Clear();
        }
    }

    String GetUserName()
    {
        LineEdit@ leName = ui.root.GetChild("leName", true);
        return leName.text;
    }

    void ExitApp()
    {
        engine.Exit();
    }

    void HandleKeyDown(StringHash eventType, VariantMap& eventData)
    {
        int key = eventData["Key"].GetInt();
        if (key == KEY_ESCAPE)
        {
            ExitApp();
        }
    }

    void HandleExitClicked()
    {
        ExitApp();
    }

    void HandleWLocalClicked()
    {
        VariantMap data;
        data["Mode"] = WRLD_MODE_LOCAL;
        data["Name"] = GetUserName();
        RequestAppStateChange(APP_STATE_WORLD, data);
    }

    void HandleWNetClicked()
    {
        VariantMap data;
        data["Mode"] = WRLD_MODE_CLIENT;
        data["Name"] = GetUserName();
        RequestAppStateChange(APP_STATE_WORLD, data);
    }

    void HandleWSrvClicked()
    {
        VariantMap data;
        data["Mode"] = WRLD_MODE_SERVER;
        data["Name"] = GetUserName();
        RequestAppStateChange(APP_STATE_WORLD, data);
    }

    void HandleTerrainClicked()
    {
        RequestAppStateChange(APP_STATE_TERRAIN);
    }

}
