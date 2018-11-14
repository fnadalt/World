#include "States.as"
#include "Vehicle.as"

class StateWorld : State
{

    int mode = WRLD_MODE_LOCAL;
    String userName = "(no name)";
    String serverAddress = "127.0.0.1";
    int serverPort = 2345;

    Vector3 characterStartPoint;
    Quaternion characterStartRotation;

    UIElement@ uiWorld;
    Controls _prevControls;
    Controls _curControls;
    Array<Client> clients;

    Node@ zoneNode;
    Node@ sunRigNode;
    Node@ waterPlaneNode;
    Terrain@ terrain;
    Zone@ zone;
    Zone@ underWaterZone;
    RenderPath@ offsceenRenderPath;

    bool isUnderWater = false;

    StateWorld()
    {
        super("World", APP_STATE_WORLD);
    }

    void Enter(State& prevState, VariantMap& data = VariantMap())
    {
        State::Enter(prevState, data);
        // Variables
        mode = data["Mode"].GetInt();
        userName = data["Name"].GetString();
        if (userName.Trimmed().empty) {
            userName = "User" + RandomInt(1000);
            ShowMessage("Empty user name. Random created: " + userName);
        }
        //
        log.Info("Enter World in mode = " + mode);
        SetupNetwork(true);
        SetupUI(true);
        SetupEvents(true);
        if (mode == WRLD_MODE_LOCAL || mode == WRLD_MODE_SERVER)
        {
            SetupScene(true);
            if (mode == WRLD_MODE_LOCAL) SetupViewports(true);
            SubscribeToEvent(scene_, "SceneUpdate", "HandleSceneUpdate");
        }
        //
        camera.farClip *= 2;
    }

    void Exit()
    {
        State::Exit();
        SetupEvents(false);
        SetupNetwork(false);
        SetupUI(false);
        SetupScene(false);
        //
        camera.farClip /= 2;
    }

    void SetupNetwork(bool flag)
    {
        if (mode != WRLD_MODE_CLIENT && mode != WRLD_MODE_SERVER) {
            return;
        }
        if (mode == WRLD_MODE_CLIENT)
        {
            if (flag) {
                VariantMap identity;
                identity["UserName"] = userName;
                network.updateFps = 50; // Increase controls send rate for better responsiveness
                network.Connect(serverAddress, serverPort, scene_, identity);
                log.Info("Server address: " + network.serverConnection.address);
            } else {
                network.Disconnect();
            }
        }
        else if (mode == WRLD_MODE_SERVER)
        {
            if (flag) {
                network.updateFps = 25;
                network.StartServer(serverPort);
            } else {
                for (uint i = 0; i < clients.length; i++) {
                    if (clients[i].connection is null) continue;
                    clients[i].connection.Disconnect();
                }
                network.StopServer();
            }
        }
    }

    void SetupUI(bool flag)
    {
        if (flag)
        {
            XMLFile@ uiFileMenu = cache.GetResource("XMLFile", "UI/Menu.xml");
            uiWorld = ui.LoadLayout(uiFileMenu);
            uiWorld.visible = false;
            ui.root.AddChild(uiWorld);
            Button@ btnGoStart = uiWorld.GetChild("btnWorldGoStart", true);
            Button@ btnSelect = uiWorld.GetChild("btnWorldSelect", true);
            Button@ btnFreeCam = uiWorld.GetChild("btnWorldFreeCam", true);
            Button@ closeButton = uiWorld.GetChild("btnCloseMenu", true);
            SubscribeToEvent(btnGoStart, "Released", "HandleBtnGoStartReleased");
            SubscribeToEvent(btnSelect, "Released", "HandleBtnSelectReleased");
            SubscribeToEvent(btnFreeCam, "Released", "HandleBtnFreeCamReleased");
            SubscribeToEvent(closeButton, "Released", "HandleBtnCloseMenu");
            //
            String windowTitleSpec = "local";
            if (mode == WRLD_MODE_CLIENT) {
                windowTitleSpec = "client";
            } else if (mode == WRLD_MODE_SERVER) {
                windowTitleSpec = "server";
            }
            SetWindowTitleAndIcon(windowTitleSpec);
        } else {
            Button@ btnGoStart = uiWorld.GetChild("btnWorldGoStart", true);
            Button@ btnSelect = uiWorld.GetChild("btnWorldSelect", true);
            Button@ btnFreeCam = uiWorld.GetChild("btnWorldFreeCam", true);
            Button@ closeButton = uiWorld.GetChild("btnCloseMenu", true);
            UnsubscribeFromEvent(btnGoStart, "Released");
            UnsubscribeFromEvent(btnSelect, "Released");
            UnsubscribeFromEvent(btnFreeCam, "Released");
            UnsubscribeFromEvent(closeButton, "Released");
            ui.root.RemoveChild(uiWorld);
            uiWorld = null;
            //
            SetWindowTitleAndIcon("");
        }
    }

    void SetupScene(bool flag)
    {
        log.Info("SetupScene");
        //
        if (flag)
        {
            if (mode == WRLD_MODE_SERVER || mode == WRLD_MODE_LOCAL)
            {
                // Load scene from file
                scene_.LoadXML(cache.GetFile("Scenes/World.xml"));
            }
            // Zone node
            zoneNode = scene_.GetChild("Zone");
            Component@[]@ zones = zoneNode.GetComponents("Zone", false);
            zone = cast<Zone>(zones[0]);
            underWaterZone = cast<Zone>(zones[1]);
            // Sun rig node
            sunRigNode = scene_.GetChild("SunRig");
            // Water plane
            waterPlaneNode = scene_.GetChild("WaterPlane");
            waterPlaneNode.worldPosition = Vector3(cameraNode.worldPosition.x, 0.0f, cameraNode.worldPosition.z);
            waterPlaneNode.worldPosition += Vector3::UP * 255 * WATER_PLANE_ALTITUDE;
            scene_.vars["OceanAltitude"] = waterPlaneNode.position.y;
            // Terrain
            Node@ terrainNode = scene_.GetChild("Terrain");
            terrain = cast<Terrain>(terrainNode.GetComponent("Terrain"));
            // Apply terrain material
            terrain.material = cache.GetResource("Material", "Materials/Terrain.xml");
            terrain.material.shaderParameters["HeightMapSize"] = terrain.heightMap.width;
            terrain.material.shaderParameters["TerrainSpacingXZ"] = terrain.spacing.x;
        } else {
            zoneNode = null;
            zone = null;
            underWaterZone = null;
            sunRigNode = null;
            waterPlaneNode = null;
            terrain = null;
        }
        //
        if (mode == WRLD_MODE_SERVER || mode == WRLD_MODE_LOCAL)
        {
            if (flag) {
                // Vegetation
                PlaceTrees();
                SpawnVehicle();
                //
                if (mode == WRLD_MODE_SERVER)
                {
                    // Disable physics interpolation to ensure clients get sent physically correct transforms
                    scene_.physicsWorld.interpolation = false;
                    console.visible = true;
                    // Set camera mode
                    VariantMap edata;
                    edata["RigType"] = CAM_RIG_FREE;
                    SendEvent("RequestCamRig", edata);
                    // Disable camera?
                    cameraNode.enabled = false;
                }
                else if (mode == WRLD_MODE_LOCAL)
                {
                    // Local (dummy) client
                    uint idx = clients.length;
                    clients.Resize(clients.length + 1);
                    clients[idx] = Client();
                    clients[idx].userName = userName;
                    // Set camera mode
                    VariantMap edata;
                    edata["Mode"] = CAM_MODE_SELECT;
                    SendEvent("RequestCamMode", edata);
                }
            } else if (!flag) { // 'if (!flag)' redundant but reading friendly
                // Hide console, clear scene
                console.visible = false;
                scene_.Clear();
                // Enable camera if not so
                if (!cameraNode.enabled)
                    cameraNode.enabled = true;
            }
        }
    }

    void SetupEvents(bool flag)
    {
        log.Info("SetupEvents");
        if (flag)
        {
            if (mode == WRLD_MODE_CLIENT || mode == WRLD_MODE_SERVER)
            {
                network.RegisterRemoteEvent("AuthFailed");
                network.RegisterRemoteEvent("SendMessage");
                network.RegisterRemoteEvent("CompleteSceneSetup");
                network.RegisterRemoteEvent("RequestCamRig");
                network.RegisterRemoteEvent("NodeSelected");
                if (mode == WRLD_MODE_CLIENT)
                {
                    SubscribeToEvent("NetworkUpdateSent", "HandleNetworkUpdateSent");
                    SubscribeToEvent("ConnectFailed", "HandleConnectFailed");
                    SubscribeToEvent("AuthFailed", "HandleAuthFailed");
                    SubscribeToEvent("CompleteSceneSetup", "HandleCompleteSceneSetup");
                }
                else if (mode == WRLD_MODE_SERVER)
                {
                    SubscribeToEvent("ClientIdentity", "HandleClientIdentity");
                    SubscribeToEvent("ClientSceneLoaded", "HandleClientSceneLoaded");
                    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected");
                }

            }
            SubscribeToEvent("KeyDown", "HandleKeyDown");
            SubscribeToEvent("SendMessage", "HandleSendMessage");
            SubscribeToEvent("NodeSelected", "HandleNodeSelected");
        } else {
            UnsubscribeFromEvent("NodeSelected");
            UnsubscribeFromEvent("SendMessage");
            UnsubscribeFromEvent("KeyDown");
            UnsubscribeFromEvent(scene_, "SceneUpdate");
            if (mode == WRLD_MODE_CLIENT || mode == WRLD_MODE_SERVER)
            {
                if (mode == WRLD_MODE_CLIENT)
                {
                    UnsubscribeFromEvent("CompleteSceneSetup");
                    UnsubscribeFromEvent("NetworkUpdateSent");
                    UnsubscribeFromEvent("ConnectFailed");
                    UnsubscribeFromEvent("AuthFailed");
                }
                else if (mode == WRLD_MODE_SERVER)
                {
                    UnsubscribeFromEvent("ClientIdentity");
                    UnsubscribeFromEvent("ClientSceneLoaded");
                    UnsubscribeFromEvent("ClientDisconnected");
                }
                network.UnregisterAllRemoteEvents();
            }
        }
    }

    void SetupViewports(bool flag)
    {
        log.Info("SetupViewports");
        if (flag) {
            Viewport@ vp1 = renderer.viewports[0];
            if(!vp1.renderPath.Load(cache.GetResource("XMLFile", "RenderPaths/ForwardDepth.xml")))
            {
                log.Error("Render path not loaded");
            }
            //
            // Offscreen
            //~ offsceenRenderPath = vp1.renderPath.Clone();
            //~ RenderPath offsceenRenderPath;
            //~ offsceenRenderPath.Append(cache.GetResource("XMLFile", "PostProcess/FX.xml"));
            //~ offsceenRenderPath.shaderParameters["BloomThreshold"] = 0.9f;
            //~ offsceenRenderPath.shaderParameters["BloomMix"] = Variant(Vector2(1.0f, 5.0f));
            //~ offsceenRenderPath.shaderParameters["BlurHInvSize"] = Variant(Vector2(1.0f, 1.0f));
            //~ offsceenRenderPath.SetEnabled("FX", true);
            //~ //
            //~ IntRect rect = IntRect(graphics.width * 2 / 3, 32, graphics.width - 32, graphics.height / 3);
            //~ Viewport@ vp2 = Viewport(scene_, camera, rect);
            //~ vp2.renderPath = offsceenRenderPath;
            //~ renderer.viewports[1] = vp2;
            //
            // Viewport
            vp1.renderPath.Append(cache.GetResource("XMLFile", "PostProcess/UnderWater.xml"));
            vp1.renderPath.shaderParameters["ElapsedTime"] = 0.0;
            vp1.renderPath.shaderParameters["OceanAltitude"] = waterPlaneNode.worldPosition.y;  // what if just position? Test shader.
            vp1.renderPath.SetEnabled("UnderWater", false);
            // Set camera position
            Node@ camDrv = scene_.GetChild("CameraDriver");
            if (camDrv !is null) {
                cameraNode.position = camDrv.worldPosition;
                cameraNode.rotation = camDrv.worldRotation;
            }
        } else {
            if (renderer.numViewports == 1) renderer.viewports[1] = null;
            offsceenRenderPath = null;
        }
    }

    // Place trees
    void PlaceTrees()
    {
        int size = int(terrain.heightMap.width * terrain.spacing.x);  // assumes height and y are equal to correspoding
        float oceanHeight = scene_.vars["OceanAltitude"].GetFloat();
        log.Info("Ocean Height = " + oceanHeight);

        const uint NUM_TREES = 2000;
        int placedCount = 0;
        while (placedCount < NUM_TREES)
        {
            // Transform
            Vector3 position(Random(size) - int(size / 2), 0.0f, Random(size) - int(size / 2));
            position.y = terrain.GetHeight(position) - 0.1f;
            if (position.y <= oceanHeight) continue;
            Quaternion rotation = Quaternion(Vector3::UP, terrain.GetNormal(position));
            // Node
            XMLFile@ xml = cache.GetResource("XMLFile", "Objects/Quebracho.xml");
            Node@ quebracho = scene.InstantiateXML(xml, position, rotation);
            quebracho.name = "Quebracho" + placedCount;
            quebracho.vars["Description"] = "Quebracho";
            quebracho.scale = Vector3::ONE * 2.75f;
            //
            placedCount++;
        }
    }

    // Spawn Mutant
    Node@ SpawnMutant()
    {
        Vector3 position = characterStartPoint;
        Quaternion rotation = characterStartRotation;
        XMLFile@ xml = cache.GetResource("XMLFile", "Objects/Mutant.xml");
        Node@ mutant = scene.InstantiateXML(xml, position, rotation);
        log.Info("Spawned Mutant id=" + mutant.id);
        return mutant;
    }

    // Spawn Vehicle
    Node@ SpawnVehicle()
    {
        Vector3 position;
        Quaternion rotation;
        // Platform
        Node@ platform = scene_.GetChild("Platform");
        if (platform !is null) {
            position = platform.position + Vector3(0.0f, 6.0f, 0.0f);
        } else {
            // Tree node
            Node@ tree = scene_.GetChild("Tree");
            if (tree !is null) {
                position = tree.position + Vector3(5.0f, 6.0f, -5.0f);
                rotation = tree.rotation;
            }
        }
        // Vehicle node
        Node@ vehicleNode = scene_.CreateChild("Vehicle");
        vehicleNode.vars["Description"] = "Vehicle";
        vehicleNode.AddTag("Selectable");
        vehicleNode.AddTag("Character");
        vehicleNode.position = position;
        vehicleNode.rotation = rotation;
        // Create the vehicle logic script object
        Vehicle@ vehicleScript = cast<Vehicle>(vehicleNode.CreateScriptObject(scriptFile, "Vehicle", LOCAL));
        // Create the rendering and physics components
        vehicleScript.Init();
        //
        log.Info("Spawned Vehicle id=" + String(vehicleNode.id));
        return vehicleNode;
    }

    Client@ GetClientByConn(Connection@ connection)
    {
        int idx = -1;
        for (uint i = 0; i < clients.length; i++)
        {
            if (clients[i].connection is connection)
            {
                idx = i;
                break;
            }
        }
        if (idx >= 0)
        {
            return clients[idx];
        }
        return null;
    }

    Client@ GetClientByNode(uint nodeId)
    {
        int idx = -1;
        for (uint i = 0; i < clients.length; i++)
        {
            if (clients[i].nodeId == nodeId)
            {
                idx = i;
                break;
            }
        }
        if (idx >= 0)
        {
            return clients[idx];
        }
        return null;
    }

    Client@ GetClientByUserName(String& userName)
    {
        int idx = -1;
        for (uint i = 0; i < clients.length; i++)
        {
            if (clients[i].userName == userName)
            {
                idx = i;
                break;
            }
        }
        if (idx >= 0)
        {
            return clients[idx];
        }
        return null;
    }

    void HandleKeyDown(StringHash eventType, VariantMap& eventData)
    {
        int key = eventData["Key"].GetInt();
        // ESC
        if (key == KEY_ESCAPE)
        {
            if (!uiWorld.visible) {
                // Make dialog visible
                uiWorld.visible = true;
                if (mode == WRLD_MODE_LOCAL || mode == WRLD_MODE_CLIENT)
                {
                    // Change camera mode
                    VariantMap edata;
                    edata["Mode"] = CAM_MODE_UI;
                    SendEvent("RequestCamMode", edata);
                    // Release client control on node?
                }
            } else {
                HandleBtnCloseMenu();
            }
        }
        // Select
        else if (key == KEY_P)
        {
            HandleBtnSelectReleased();
            ShowMessage("Select", 1.5f);
        }
    }

    void HandleSceneUpdate(StringHash eventType, VariantMap& eventData)
    {

        float timeStep = eventData["timeStep"].GetFloat();

        // Local and client code
        if (mode == WRLD_MODE_LOCAL || mode == WRLD_MODE_CLIENT)
        {
            // Camera position
            Vector2 cameraPositionH = Vector2(cameraNode.worldPosition.x, cameraNode.worldPosition.z);
            // Zone node
            zoneNode.position = Vector3(cameraPositionH.x, 0.0f, cameraPositionH.y);
            // Sun rig node
            sunRigNode.position = Vector3(cameraPositionH.x, 0.0f, cameraPositionH.y);
            // Water plane
            float oceanAltitude = scene_.vars["OceanAltitude"].GetFloat();
            waterPlaneNode.position = Vector3(cameraPositionH.x, oceanAltitude, cameraPositionH.y);
            if (cameraNode.worldPosition.y < oceanAltitude && !isUnderWater) {
                log.Info("Flip water plane downwards, camera altitude=" + cameraNode.worldPosition.y);
                waterPlaneNode.rotation = Quaternion(180.0, 0.0, 0.0);
                isUnderWater = true;
                //~ zone.enabled = false;
                //~ underWaterZone.enabled = true;
                renderer.viewports[0].renderPath.SetEnabled("UnderWater", true);
            }
            else if (cameraNode.worldPosition.y > oceanAltitude && isUnderWater) {
                log.Info("Flip water plane upwards, camera altitude=" + cameraNode.worldPosition.y);
                waterPlaneNode.rotation = Quaternion(0.0, 0.0, 0.0);
                isUnderWater = false;
                //~ zone.enabled = true;
                //~ underWaterZone.enabled = false;
                renderer.viewports[0].renderPath.SetEnabled("UnderWater", false);
            }
            if (isUnderWater)
            {
                renderer.viewports[0].renderPath.shaderParameters["ElapsedTime"] = scene_.elapsedTime;
                if (offsceenRenderPath !is null) offsceenRenderPath.shaderParameters["ElapsedTime"] = scene_.elapsedTime;
            }

            // Controls
            _prevControls = _curControls;
            _curControls.Set(CTRL_ALL, false);
            if (console is null || !console.visible)
            {
                Controls _dummyControls = _prevControls;
                _dummyControls.Set(CTRL_FORWARD, input.keyDown[KEY_W]);
                _dummyControls.Set(CTRL_BACK, input.keyDown[KEY_S]);
                _dummyControls.Set(CTRL_LEFT, input.keyDown[KEY_A]);
                _dummyControls.Set(CTRL_RIGHT, input.keyDown[KEY_D]);
                _dummyControls.Set(CTRL_JUMP, input.keyDown[KEY_SPACE]);
                _dummyControls.Set(CTRL_ACTION, input.keyDown[KEY_TAB]);
                _dummyControls.Set(CTRL_PICK, input.keyDown[KEY_CTRL]);
                if (input.keyDown[KEY_Q])
                    _dummyControls.yaw = _curControls.yaw - 120.0f * timeStep;
                if (input.keyDown[KEY_E])
                    _dummyControls.yaw = _curControls.yaw + 120.0f * timeStep;
                //
                if (mode == WRLD_MODE_LOCAL)
                {
                    // Local code
                    _curControls = _dummyControls;
                    Client@ client = GetClientByConn(null);
                    //~ debugHud.SetAppStats("client.nodeId", String(client.nodeId));
                    //~ debugHud.SetAppStats("client.userName", client.userName);
                    if (client !is null) {
                        Node@ node = scene_.GetNode(client.nodeId);
                        if (node !is null) {
                            debugHud.SetAppStats("client.nodeName", node.name);
                            node.vars["buttons"] = _curControls.buttons;
                            node.vars["yaw"] = _curControls.yaw;
                            node.vars["pitch"] = _curControls.pitch;
                            //~ debugHud.SetAppStats("vars.buttons", node.vars["buttons"].ToString());
                            //~ debugHud.SetAppStats("Controlled pos", node.position.ToString());
                        } else {
                            //~ debugHud.SetAppStats("vars.buttons", "null");
                        }
                    }
                }
                else if (mode == WRLD_MODE_CLIENT && network.serverConnection !is null)
                {
                    // Client code
                    _curControls = _dummyControls;
                    network.serverConnection.controls.yaw = _curControls.yaw;
                    network.serverConnection.controls.pitch = _curControls.pitch;
                    network.serverConnection.controls.buttons |= _curControls.buttons;
                    network.serverConnection.position = cameraNode.worldPosition;
                }

            }
        }
        // Server code
        else if (mode == WRLD_MODE_SERVER)
        {
            for (uint i = 0; i < clients.length; i++)
            {
                Client@ client = clients[i];
                uint nodeId = client.nodeId;
                if (nodeId == 0) continue;
                Node@ node = scene_.GetNode(nodeId);
                node.vars["buttons"] = client.connection.controls.buttons;
                node.vars["yaw"] = client.connection.controls.yaw;
                node.vars["pitch"] = client.connection.controls.pitch;
            }
        }

    if (drawDebug)
        physicsWorld.DrawDebugGeometry(true);

    }

    void HandleBtnGoStartReleased()
    {
        RequestAppStateChange(APP_STATE_START);
    }

    void HandleBtnSelectReleased()
    {
        log.Info("HandleBtnSelectReleased");
        uiWorld.visible = false;
        VariantMap edata;
        edata["Mode"] = CAM_MODE_SELECT;
        SendEvent("RequestCamMode", edata);
    }

    void HandleBtnFreeCamReleased()
    {
        log.Info("HandleBtnFreeCamReleased");
        // Client
        Client@ client = GetClientByUserName(userName);
        if (client !is null) {
            client.nodeId = 0;
        }
        // UI
        uiWorld.visible = false;
        // Camera
        VariantMap edata;
        edata["Mode"] = CAM_RIG_FREE;
        SendEvent("RequestCamRig", edata);
    }

    void HandleBtnCloseMenu()
    {
        uiWorld.visible = false;
        VariantMap edata;
        edata["Mode"] = CAM_MODE_RIG;
        SendEvent("RequestCamMode", edata);
    }

    void HandleSendMessage(StringHash eventType, VariantMap& eventData)
    {
        String msg = eventData["Message"].GetString();
        int timeout = eventData["Timeout"].GetInt();
        if (timeout > 0.0f) {
            ShowMessage(msg, timeout);
        } else {
            ShowMessage(msg);
        }
    }

    void HandleNodeSelected(StringHash eventType, VariantMap& eventData)
    {
        log.Info("HandleNodeSelected");
        // Get node
        int nodeId = eventData["NodeId"].GetInt();
        Node@ node = scene_.GetNode(nodeId);
        if (node is null) {
            log.Error("Null node selected, id=" + nodeId);
            return;
        }
        log.Info("Node selected: " + node.name + " id=" + String(nodeId));
        // Is a Character?
        if (node.HasTag(TAG_CHARACTER)) {
            log.Info("Node selected is a character");
            // Model node
            Node@ modelNode;
            if (node.name == "Model") {
                modelNode = node;
                node = modelNode.parent;
            } else {
                modelNode = node.GetChild("Model");
                if (modelNode is null) {
                    log.Warning("No Model node, modelNode = node");
                    modelNode = node;
                }
            }
            // On local and server mode
            if (mode == WRLD_MODE_LOCAL || mode == WRLD_MODE_SERVER)
            {
                Connection@ connection = (mode == WRLD_MODE_SERVER) ? GetEventSender() : null;
                // Change controlled node
                VariantMap edata;
                edata["RigType"] = CAM_RIG_THRDP;
                edata["NodeId"] = nodeId;
                //~ SendEvent("ControlledNodeChanged", edata); not used anymore?
                // Is node under control?
                Client@ client = GetClientByNode(nodeId);
                if (client !is null && connection !is client.connection)
                {
                    String msg = "Client id=" + String(nodeId) + " is already under control";
                    log.Info(msg);
                    if (mode == WRLD_MODE_LOCAL) {
                        ShowMessage(msg);
                    } else if (mode == WRLD_MODE_SERVER) {
                        VariantMap edata1;
                        edata1["Message"] = msg;
                        connection.SendRemoteEvent("SendMessage", false, edata1);
                    }
                    return; // !!!
                }
                // Update Client data
                Client@ client1 = GetClientByConn(connection);
                if (client1 !is null) {
                    client1.nodeId = nodeId;
                }
                // Update controls data
                _curControls.Set(CTRL_ALL, false);
                _curControls.yaw = node.rotation.yaw;
                _curControls.pitch = node.rotation.pitch;
                // Change camera rig type
                if (mode == WRLD_MODE_LOCAL)
                {
                    edata["NodeId"] = modelNode.id;
                    SendEvent("RequestCamRig", edata);
                }
                else if (mode == WRLD_MODE_SERVER)
                {
                    Client@ client2 = GetClientByNode(nodeId);
                    if (client2 !is null && client2.connection !is null)
                    {
                        log.Info("RequestCamRig to client id=" + String(client2.userName));
                        edata["NodeId"] = modelNode.id;
                        client2.connection.SendRemoteEvent("RequestCamRig", true, edata);
                    }
                }
            }
            // On client mode, send event...
            else if (mode == WRLD_MODE_CLIENT && network.serverConnection !is null)
            {
                log.Info("mode client");
                VariantMap edata;
                edata["NodeId"] = node.id;
                network.serverConnection.SendRemoteEvent("NodeSelected", true, edata);
            }
        }
    }

    // Server code
    void HandleClientIdentity(StringHash eventType, VariantMap& eventData)
    {
        Connection@ connection = GetEventSender();
        // Get user name
        String _userName = connection.identity["UserName"].GetString();
        // user name already registered?
        bool userNameExists = (GetClientByUserName(_userName) !is null);
        if (userNameExists) {
            VariantMap edata;
            edata["Message"] = "User name '" + _userName + "' already exists";
            connection.SendRemoteEvent("AuthFailed", true, edata);
        }
        // Assign scene to begin replicating it to the client
        connection.scene = scene_;
        log.Info("HandleClientIdentity UserName=" + _userName);
    }

    // Server code
    void HandleClientSceneLoaded(StringHash eventType, VariantMap& eventData)
    {
        log.Info("HandleClientSceneLoaded");
        // Now client is actually ready to begin. If first player, clear the scene and restart the game
        Connection@ connection = GetEventSender();
        // Get user name
        String _userName = connection.identity["UserName"].GetString();
        // New Client entry?
        Client@ client = GetClientByConn(connection);
        // ...no, create
        if (client is null)
        {
            log.Info("Create new Client entry for userName=" + userName);
            uint clientIdx = clients.length;
            clients.Resize(clients.length + 1);
            clients[clientIdx] = Client();
            clients[clientIdx].connection = connection;
            clients[clientIdx].userName = _userName;
        }
        // Set camera mode
        connection.SendRemoteEvent("CompleteSceneSetup", true);
    }

    // Server code
    void HandleClientDisconnected(StringHash eventType, VariantMap& eventData)
    {
        log.Info("HandleClientDisconnected");
        Connection@ connection = GetEventSender();
        int idx = -1;
        for (uint i = 0; i < clients.length; i++)
        {
            if (clients[i].connection is connection)
            {
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            log.Warning("Registered client disconnected for which no client structure was found.");
            return;
        }
        log.Info("Client disconnected: " + clients[idx].userName);
        Node@ node = scene_.GetNode(clients[idx].nodeId);
        if (node !is null) {
            node.Remove();
        }
        clients.Erase(idx);
    }

    // Client code
    void HandleNetworkUpdateSent()
    {
        // Clear accumulated buttons from the network controls
        if (network.serverConnection !is null)
            network.serverConnection.controls.Set(CTRL_ALL, false);
    }

    // Client code
    void HandleConnectFailed()
    {
        ShowMessage("Connection to server failed. Press ESC.");
        uiWorld.visible = true;
    }

    // Client code
    void HandleAuthFailed(StringHash eventType, VariantMap& eventData)
    {
        // Message
        String msg = eventData["Message"].GetString();
        ShowMessage("Authentication to server failed:\n" + msg + "\nPress ESC.");
        // Clear user name
        userName.Clear();
        // Disconnect
        Connection@ connection = GetEventSender();
        connection.Disconnect();
    }

    // Client code
    void HandleCompleteSceneSetup(StringHash eventType, VariantMap& eventData)
    {
        log.Info("CompleteSceneSetup");
        //
        SetupScene(true);
        SetupViewports(true);
        SetupEvents(true);
        SubscribeToEvent(scene_, "SceneUpdate", "HandleSceneUpdate");
        // Disable scripts and physics
        log.Info("Remove physics and scripting from replicated nodes:");
        Node@[]@ replicated = scene_.GetChildrenWithScript(true);
        for (uint i = 0; i < replicated.length; i++)
        {
            Node@ node = replicated[i];
            if (!node.replicated){
                log.Info("Skip " + node.name);
                continue;
            }
            log.Info("Disable script from " + node.name);
            // scripts
            Component@[]@ scripts = node.GetComponents("ScriptInstance");
            for (uint j = 0; j < scripts.length; j++)
            {
                Component@ script = scripts[j];
                script.enabled = false;
            }
        }
        replicated = scene_.GetChildrenWithComponent("RigidBody");
        for (uint i = 0; i < replicated.length; i++)
        {
            Node@ node = replicated[i];
            if (!node.replicated){
                log.Info("Skip " + node.name);
                continue;
            }
            log.Info("Disable physics from " + node.name);
            node.GetComponent("RigidBody").enabled = false;
            if (node.HasComponent("CollisionShape")) node.GetComponent("CollisionShape").enabled = false;
        }
        // Camera
        VariantMap edata;
        edata["Mode"] = CAM_MODE_SELECT;
        SendEvent("RequestCamMode", edata);
    }

}

class Client
{
    String userName;
    Connection@ connection;
    uint nodeId;

    Client()
    {
        userName = "(no name)";
        connection = null;
        nodeId = 0;
    }

    void Terminate()
    {
        connection = null;
    }

}
