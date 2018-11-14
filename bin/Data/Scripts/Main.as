#include "Constants.as"
#include "Start.as"
#include "World.as"
#include "Terrain.as"

// Global application variables
Scene@ scene_;
Node@ cameraNode;
Camera@ camera;
UIElement@ uiMessage;
State@ appState = StateNull();

bool drawDebug;

void Start()
{
    log.Info("Start application");

    // Basic setup
    log.level = LOG_INFO;
    //
    SetWindowTitleAndIcon();
    CreateConsoleAndDebugHud();
    //
    SetupInput();
    SetupUI();
    SetupSceneAndViewport();
    //
    SubscribeToEvent("ExitRequested", "HandleExitRequested");
    SubscribeToEvent("KeyDown", "HandleKeyDown");

    // Init state
    RequestAppStateChange(APP_STATE_START);

}

void Stop()
{
    log.Info("Stop application");
    UnsubscribeFromAllEvents();
    RequestAppStateChange(APP_STATE_NULL);
    appState = null;
    uiMessage.Remove();
    uiMessage = null;
    camera = null;
    cameraNode.Remove();
    cameraNode = null;
    UnsubscribeFromEvents(scene_);
    scene_.Clear();
}

void SetWindowTitleAndIcon(String& spec = String())
{
    log.Info("SetWindowTitleAndIcon");
    //
    String title = "World";
    if (!spec.empty)
        title += " - " + spec;
    //
    Image@ icon = cache.GetResource("Image", "Textures/UrhoIcon.png");
    graphics.windowIcon = icon;
    graphics.windowTitle = title;
}

void CreateConsoleAndDebugHud()
{
    log.Info("CreateConsoleAndDebugHud");
    // Get default style
    XMLFile@ xmlFile = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");
    if (xmlFile is null)
        return;

    // Create console
    Console@ console = engine.CreateConsole();
    console.defaultStyle = xmlFile;
    console.background.opacity = 0.8f;

    // Create debug HUD
    DebugHud@ debugHud = engine.CreateDebugHud();
    debugHud.defaultStyle = xmlFile;
}

void SetupInput()
{
    log.Info("SetupInput");
    // Mouse setup
    input.mouseMode = MM_ABSOLUTE;
}

void SetupUI()
{
    log.Info("SetupUI");

    // Set up global UI style into the root UI element
    XMLFile@ style = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");
    ui.root.defaultStyle = style;

    // Message
    XMLFile@ uiFileMsg = cache.GetResource("XMLFile", "UI/Message.xml");
    uiMessage = ui.LoadLayout(uiFileMsg);
    uiMessage.visible = false;
    ui.root.AddChild(uiMessage);

}

void SetupSceneAndViewport()
{
    log.Info("SetupSceneAndViewport");

    // Scene, camera and viewport, shared across the app
    scene_ = Scene("World");
    cameraNode = Node();
    cameraNode.position = Vector3(0.0f, 10.0f, 0.0f);
    camera = cameraNode.CreateComponent("Camera");
    camera.nearClip = 0.5f;
    camera.farClip = 256.0f;

    Viewport@ vp0 = Viewport(scene_, camera);
    renderer.viewports[0] = vp0;

    // Enable access to this script file & scene from the console
    script.defaultScene = scene_;
    script.defaultScriptFile = scriptFile;
}

void ShowMessage(String& text, float timeout = 3.0f)
{
    if (uiMessage.visible)
        HideMessage();
    Text@ t3dText = cast<Text>(uiMessage.GetChild("Text"));
    t3dText.text = text;
    uiMessage.visible = true;
    DelayedExecute(timeout, false, "void HideMessage()");
}

void HideMessage()
{
    Text@ t3dText = cast<Text>(uiMessage.GetChild("Text"));
    uiMessage.visible = false;
    ClearDelayedExecute("void HideMessage()");
}

void RequestAppStateChange(int newAppStateId, VariantMap& data = VariantMap())
{
    State@ curState = appState;
    State@ newState = GetState(newAppStateId);

    log.Info("Change app state from " + curState.name + " to " + newState.name);
    if (curState.id == newState.id) {
        log.Warning("Same state, do nothing");
        return;
    }

    curState.Exit();
    newState.Enter(curState, data);

    curState = null;
    appState = null;
    appState = newState;

}

void HandleExitRequested(StringHash eventType, VariantMap& eventData)
{
    log.Info("HandleExitRequested");
}

void HandleKeyDown(StringHash eventType, VariantMap& eventData)
{
    int key = eventData["Key"].GetInt();

    // Toggle console with F1
    if (key == KEY_F1) {
        console.Toggle();
    }
    // Toggle debug HUD with F2
    else if (key == KEY_F2) {
        debugHud.ToggleAll();
    }
    // Toggle draw debug F3
    else if (key == KEY_F3) {
        drawDebug = !drawDebug;
    }
    // Toggle fullscreen F4
    else if (key == KEY_F4) {
        graphics.ToggleFullscreen();
    }
    // Take screenshot
    if (key == KEY_F6)
    {
        Image@ screenshot = Image();
        graphics.TakeScreenShot(screenshot);
        // Here we save in the Data folder with date and time appended
        String filePath = fileSystem.programDir + "Screenshot_" + time.timeStamp.Replaced(':', '_').Replaced('.', '_').Replaced(' ', '_') + ".png";
        screenshot.SavePNG(filePath);
        //
        ShowMessage("Screenshot saved to " + filePath);
    }

}

State@ GetState(int appStateId)
{
    if (appStateId == APP_STATE_NULL) {
        return StateNull();
    }
    else if (appStateId == APP_STATE_START) {
        return StateStart();
    }
    else if (appStateId == APP_STATE_WORLD) {
        return StateWorld();
    }
    else if (appStateId == APP_STATE_TERRAIN) {
        return StateTerrain();
    }
    log.Error("State id not recognized: " + appStateId);
    return StateNull();
}
