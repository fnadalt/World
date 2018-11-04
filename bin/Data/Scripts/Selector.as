#include "Constants.as"

class Selector : ScriptObject
{

    float RefreshRate = 15.0f;
    float RayDistance = 50.0f;

    float _timer = 0.0f;
    Camera@ _camera;
    Node@ _cameraNode;
    Node@ _focusedNode;
    Node@ _focusedNodeName;
    bool _enabled = false;

    void Start()
    {
        log.Info("Selector::Start");

        Viewport@ vp0 = renderer.viewports[0];
        _camera = vp0.camera;
        _cameraNode = _camera.node;

        SubscribeToEvent("MouseButtonUp", "HandleMouseButtonUp");
        SubscribeToEvent("CamModeChanged", "HandleCamModeChanged");
    }

    void DelayedStart()
    {
        log.Info("Selector::DelayedStart");
        _focusedNodeName = scene.GetChild("ObjectName");
        if (_focusedNodeName is null) {
            log.Error("for some strange reason, _focusedNodeName is null");
        }
    }

    void Stop()
    {
        log.Info("Selector::Stop");
        UnsubscribeFromEvent("MouseButtonUp");
        UnsubscribeFromEvent("CamModeChanged");
        _cameraNode = null;
        _camera = null;
        _focusedNode = null;
        _focusedNodeName = null;
    }

    void Load(Deserializer& deserializer)
    {
        RefreshRate = deserializer.ReadFloat();
        RayDistance = deserializer.ReadFloat();
    }

    void Save(Serializer& serializer)
    {
        serializer.WriteFloat(RefreshRate);
        serializer.WriteFloat(RayDistance);
    }

    void Update(float timeStep)
    {
        if (!_enabled)
            return;

        _timer += timeStep;
        if (_timer < 1.0f / RefreshRate)
            return;
        _timer -= 1.0f / RefreshRate;

        IntVector2 mpos = input.mousePosition;
        //~ debugHud.SetAppStats("mousePos", (float(mpos.x) / graphics.width) + ", " + (float(mpos.y) / graphics.height));
        Viewport@ vp = renderer.viewports[0];
        Ray cameraRay = vp.GetScreenRay(mpos.x, mpos.y);
        RayQueryResult result = scene.octree.RaycastSingle(cameraRay, RAY_TRIANGLE, RayDistance, DRAWABLE_GEOMETRY);
        //~ debugHud.SetAppStats("RQR d=", String(result.distance));
        if (result.node !is null && result.node !is _focusedNode)
        {
            _focusedNode = result.node;
            ShowFocusedNodeName();
        }
        else if (result.node is null && _focusedNode !is null) {
            _focusedNode = null;
            HideFocusedNodeName();
        }

    }

    void HandleMouseButtonUp(StringHash eventType, VariantMap& eventData)
    {
        if (_focusedNode is null)
            return;

        if (!_focusedNode.HasTag(TAG_SELECTABLE))
        {
            Node@ parent = _focusedNode.parent;
            if (parent !is null && parent.HasTag(TAG_SELECTABLE))
            {
                _focusedNode = parent;
            } else {
                return;
            }
        }

        VariantMap edata;
        edata["NodeId"] = _focusedNode.id;
        SendEvent("NodeSelected", edata);
    }

    void HandleCamModeChanged(StringHash eventType, VariantMap& eventData)
    {
        HideFocusedNodeName();
        _focusedNode = null;

        int mode = eventData["Mode"].GetInt();
        if (mode == CAM_MODE_SELECT) {
            _enabled = true;
        } else {
            _enabled = false;
        }

    }

    void HideFocusedNodeName()
    {
        if (_focusedNodeName is null) return;
        _focusedNodeName.enabled = false;
    }

    void ShowFocusedNodeName()
    {
        //~ log.Info("ShowFocusedNodeName");
        HideFocusedNodeName();
        if (_focusedNode is null)
            return;
        //
        Vector3 diff = _focusedNode.worldPosition - _cameraNode.worldPosition;
        float dist = diff.length;
        Vector3 namePosition = _cameraNode.worldPosition + diff.Normalized() * dist * 0.5f + Vector3(0.0f, 1.0f, 0.0f);
        //
        _focusedNodeName.enabled = true;
        _focusedNodeName.worldPosition = namePosition;
        //
        String description = _focusedNode.vars["Description"].GetString();
        //~ log.Info("Description " + description);
        Text3D@ text = cast<Text3D>(_focusedNodeName.GetComponent("Text3D"));
        text.text = description.empty ? "?" : description;
    }

}
