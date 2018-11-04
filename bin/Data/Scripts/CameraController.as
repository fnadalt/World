#include "Constants.as"
#include "CameraRigs.as"

class CameraController : ScriptObject
{

    float RefreshRate = 15.0f;

    Node@ _cameraNode;
    Camera@ _camera;
    Node@ _targetNode;
    CamRig@ _rig;

    float _timer = 0.0f;
    int _mode;
    int _rig_type = CAM_RIG_FREE;

    CameraController()
    {
        _rig = CamRig(scene, _cameraNode);
    }

    void Start()
    {
        log.Info("CameraController::Start");

        SubscribeToEvent("RequestCamMode", "HandleRequestCamMode");
        SubscribeToEvent("RequestCamRig", "HandleRequestCamRig");

        Viewport@ vp0 = renderer.viewports[0];
        _camera = vp0.camera;
        _cameraNode = _camera.node;

         VariantMap eventData;
        eventData["Mode"] = CAM_MODE_UI;
        SendEvent("RequestCamMode", eventData);
   }

    void Stop()
    {
        log.Info("CameraController::Stop");
        UnsubscribeFromEvent("RequestCamMode");
        UnsubscribeFromEvent("RequestCamRig");
        if (HasSubscribedToEvent("MouseButtonUp")) UnsubscribeFromEvent("MouseButtonUp");
        _camera = null;
        _cameraNode = null;
        _targetNode = null;
        _rig.Terminate();
        _rig = null;
    }

    void HandleMouseUp(StringHash eventType, VariantMap& eventData)
    {
        int button = eventData["Button"].GetInt();

        if (_mode == CAM_MODE_SELECT && button == MOUSEB_RIGHT) {
            VariantMap edata;
            edata["Mode"] = CAM_MODE_RIG;
            SendEvent("RequestCamMode", edata);
        }
    }

    void HandleRequestCamMode(StringHash eventType, VariantMap& eventData)
    {
        int mode = eventData["Mode"].GetInt();

        log.Info("Set camera mode: " + mode);
        if (mode == CAM_MODE_SELECT || mode == CAM_MODE_UI) {
            _rig.Terminate();
            _rig = CamRig(scene, _cameraNode);
            input.mouseVisible = true;
        }
        else if (mode == CAM_MODE_RIG) {
            if (_rig_type == CAM_RIG_FREE) {
                log.Info("Camera rig free");
                _rig.Terminate();
                _rig = CamRigFree(scene, _cameraNode);
                input.mouseVisible = false;
            }
            else if (_rig_type == CAM_RIG_FSTP && _targetNode !is null) {
                log.Info("Camera rig first person");
                _rig.Terminate();
                _rig = CamRigFstp(scene, _cameraNode);
                input.mouseVisible = false;
            }
            else if (_rig_type == CAM_RIG_THRDP && _targetNode !is null) {
                log.Info("Camera rig third person");
                _rig.Terminate();
                _rig = CamRigThrdp(scene, _cameraNode);
                input.mouseVisible = false;
            }
            else {
                log.Error("Camera rig not recognized and/or no target node set");
                return;
            }
        } else {
            log.Error("Camera mode not recognized");
            return;
        }
        _mode = mode;
        _rig.SetTargetNode(_targetNode);
        _rig.Init();

        if (_mode == CAM_MODE_SELECT) {
            SubscribeToEvent("MouseButtonUp", "HandleMouseUp");
        } else {
            if (HasSubscribedToEvent("MouseButtonUp")) UnsubscribeFromEvent("MouseButtonUp");
        }

        VariantMap edata;
        edata["Mode"] = _mode;
        SendEvent("CamModeChanged", edata);
    }

    void HandleRequestCamRig(StringHash eventType, VariantMap& eventData)
    {
        int rigType = eventData["RigType"].GetInt();

        if(rigType == CAM_RIG_FSTP || rigType == CAM_RIG_THRDP) {
            int targetNodeId =  eventData["NodeId"].GetInt();
            Node@ targetNode = scene.GetNode(targetNodeId);
            if (targetNode is null) {
                log.Error("HandleRequestCamRig targetNode is null " + targetNodeId);
                return;
            }
            _targetNode = targetNode;
        }

        _rig_type = rigType;

        VariantMap edata;
        edata["Mode"] = CAM_MODE_RIG;
        SendEvent("RequestCamMode", edata);
    }

    void Update(float timeStep)
    {
        _timer += timeStep;
        if (_timer < 1.0f / RefreshRate)
            return;
        _timer -= 1.0f / RefreshRate;

        _rig.MoveCamera(timeStep);
    }

}
