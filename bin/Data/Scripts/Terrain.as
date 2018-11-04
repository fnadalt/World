#include "States.as"

class StateTerrain : State
{

    UIElement@ uiTerrain;

    Node@ zoneNode;
    Node@ sunRigNode;
    Node@ waterPlaneNode;

    StateTerrain()
    {
        super("Terrain", APP_STATE_TERRAIN);
    }

    void Enter(State& prevState, VariantMap& data = VariantMap())
    {
        State::Enter(prevState, data);
        // Variables
        SetupUI(true);
        SetupScene(true);
        SetupEvents(true);
        //
        SetupTerrain();
        PlaceCamera(Vector3::ZERO);
    }

    void Exit()
    {
        State::Exit();
        SetupEvents(false);
        SetupUI(false);
        SetupScene(false);
        zoneNode = null;
        sunRigNode = null;
        waterPlaneNode = null;
    }

    void SetupUI(bool flag)
    {
        if (flag)
        {
            XMLFile@ uiFileMenu = cache.GetResource("XMLFile", "UI/Terrain.xml");
            uiTerrain = ui.LoadLayout(uiFileMenu);
            uiTerrain.visible = false;
            ui.root.AddChild(uiTerrain);
            Button@ btnGoStart = uiTerrain.GetChild("btnWorldGoStart", true);
            Button@ closeButton = uiTerrain.GetChild("btnCloseMenu", true);
            Button@ btnGoTo = uiTerrain.GetChild("btnGoTo", true);
            SubscribeToEvent(btnGoStart, "Released", "HandleBtnGoStartReleased");
            SubscribeToEvent(closeButton, "Released", "HandleBtnCloseMenu");
            SubscribeToEvent(btnGoTo, "Released", "HandleBtnGoTo");
            //
            SetWindowTitleAndIcon("terrain");
        } else {
            Button@ btnGoStart = uiTerrain.GetChild("btnWorldGoStart", true);
            Button@ closeButton = uiTerrain.GetChild("btnCloseMenu", true);
            Button@ btnGoTo = uiTerrain.GetChild("btnGoTo", true);
            UnsubscribeFromEvent(btnGoStart, "Released");
            UnsubscribeFromEvent(closeButton, "Released");
            UnsubscribeFromEvent(btnGoTo, "Released");
            ui.root.RemoveChild(uiTerrain);
            uiTerrain = null;
            //
            SetWindowTitleAndIcon("");
        }
    }

    void SetupScene(bool flag)
    {
        if (flag) {
            // Load scene from file
            scene_.LoadXML(cache.GetFile("Scenes/World.xml"));
            // Remove some children
            Array<Node@> toBeRemoved;
            for (uint i = 0; i < scene_.numChildren; i++)
            {
                Node@ child = scene_.children[i];
                log.Info("Remove " + child.name + "?");
                if (!child.HasTag("Environment")) {
                    log.Info("Will be removed: " + child.name);
                    toBeRemoved.Resize(toBeRemoved.length + 1);
                    toBeRemoved[toBeRemoved.length - 1] = child;
                }
            }
            for (uint i = 0; i < toBeRemoved.length; i++)
            {
                Node@ node = toBeRemoved[i];
                node.Remove();
            }
            // Zone node
            //~ zoneNode = scene_.GetChild("Zone");
            // Sun rig node
            sunRigNode = scene_.GetChild("SunRig");
            // Free camera
            VariantMap edata;
            edata["RigType"] = CAM_RIG_FREE;
            SendEvent("RequestCamRig", edata);
        } else if (!flag) { // 'if (!flag)' redundant but reading friendly
            // Hide console, clear scene
            console.visible = false;
            scene_.Clear();
        }
    }

    void SetupEvents(bool flag)
    {
        if (flag)
        {
            SubscribeToEvent(scene_, "SceneUpdate", "HandleSceneUpdate");
            SubscribeToEvent("KeyDown", "HandleKeyDown");
        } else {
            UnsubscribeFromEvent("KeyDown");
            UnsubscribeFromEvent(scene_, "SceneUpdate");
        }
    }

    void SetupTerrain()
    {
        // Get terrain
        Node@ terrainNode = scene_.GetChild("Terrain");
        Terrain@ terrain = cast<Terrain>(terrainNode.GetComponent("Terrain"));
        // Apply topography and scale
        float scale_xz = 4.0f;
        float scale_y = 0.33f;
        terrain.heightMap = cache.GetResource("Image", "Textures/topography.png");
        terrain.spacing = Vector3(scale_xz, scale_y, scale_xz);
        // Apply material
        terrain.material = cache.GetResource("Material", "Materials/Terrain.xml");
        terrain.material.shaderParameters["HeightMapSize"] = terrain.heightMap.width;
        terrain.material.shaderParameters["TerrainSpacingXZ"] = terrain.spacing.x;
        // Water plane
        waterPlaneNode = scene_.GetChild("WaterPlane");
        waterPlaneNode.worldPosition = Vector3(cameraNode.worldPosition.x, 0.0f, cameraNode.worldPosition.z);
        waterPlaneNode.worldPosition += Vector3::UP * 255 * WATER_PLANE_ALTITUDE * scale_y;
        scene_.vars["OceanAltitude"] = waterPlaneNode.position.y;
    }

    void PlaceCamera(const Vector3& worldPosition)
    {
        //
        Node@ terrainNode = scene_.GetChild("Terrain");
        Terrain@ terrain = cast<Terrain>(terrainNode.GetComponent("Terrain"));
        //
        float altitude = terrain.GetHeight(worldPosition);
        cameraNode.worldPosition = Vector3(worldPosition.x, altitude + 50.0f, worldPosition.z);
    }

    void HandleKeyDown(StringHash eventType, VariantMap& eventData)
    {
        int key = eventData["Key"].GetInt();
        // ESC
        if (key == KEY_ESCAPE)
        {
            if (!uiTerrain.visible) {
                // Make dialog visible
                uiTerrain.visible = true;
                // Change camera mode
                VariantMap edata;
                edata["Mode"] = CAM_MODE_UI;
                SendEvent("RequestCamMode", edata);
            } else {
                HandleBtnCloseMenu();
            }
        }
        else if (key == KEY_P) {
            waterPlaneNode.enabled = !waterPlaneNode.enabled;
        }
    }

    void HandleSceneUpdate(StringHash eventType, VariantMap& eventData)
    {
        debugHud.SetAppStats("CamWorldPos", cameraNode.worldPosition.ToString());
        // Camera position
        Vector2 cameraPositionH = Vector2(cameraNode.worldPosition.x, cameraNode.worldPosition.z);
        // Zone node
        //~ zoneNode.position = Vector3(cameraPositionH.x, 0.0f, cameraPositionH.y);
        // Sun rig node
        sunRigNode.position = Vector3(cameraPositionH.x, 0.0f, cameraPositionH.y);
        // Water plane
        waterPlaneNode.position = Vector3(cameraPositionH.x, scene_.vars["OceanAltitude"].GetFloat(), cameraPositionH.y);
    }

    void HandleBtnGoStartReleased()
    {
        RequestAppStateChange(APP_STATE_START);
    }

    void HandleBtnCloseMenu()
    {
        uiTerrain.visible = false;
        VariantMap edata;
        edata["Mode"] = CAM_MODE_RIG;
        SendEvent("RequestCamMode", edata);
    }

    void HandleBtnGoTo()
    {
        LineEdit@ leX = cast<LineEdit>(ui.root.GetChild("leX", true));
        LineEdit@ leY = cast<LineEdit>(ui.root.GetChild("leY", true));
        float x = leX.text.ToFloat();
        float y = leY.text.ToFloat();
        Vector3 position = Vector3(x, 0.0f, y);
        log.Info("Go to " + position.ToString());
        PlaceCamera(position);
    }

}
