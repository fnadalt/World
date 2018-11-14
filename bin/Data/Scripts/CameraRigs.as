float yaw = 0.0f;
float pitch = 5.0f;

class CamRig
{

    float FreeMoveSpeed = 75.0f;
    float MouseSensitivity = 0.1f;

    Scene@ _scene;
    Node@ _cameraNode;
    Node@ _targetNode;

    CamRig(Scene@ scene, Node@ cameraNode)
    {
        _scene = scene;
        _cameraNode = cameraNode;
    }

    void SetTargetNode(Node@ node) final
    {
        _targetNode = node;
    }

    void Init() {}

    void Terminate()
    {
        _scene = null;
        _cameraNode = null;
        _targetNode = null;
    }

    void MoveCamera(float timeStep) {}

}

class CamRigFree : CamRig
{

    CamRigFree(Scene@ scene, Node@ cameraNode)
    {
        super(scene, cameraNode);
    }

    void Init()
    {
        log.Info("Init()");
        Vector3 wPos = _cameraNode.worldPosition;
        _scene.AddChild(_cameraNode);
        _cameraNode.worldPosition = wPos;
        //~ UpdateCameraPosition();
    }

    void MoveCamera(float timeStep)
    {

        // Use this frame's mouse motion to adjust camera node yaw and pitch. Clamp the pitch between -90 and 90 degrees
        IntVector2 mouseMove = input.mouseMove;
        yaw += MouseSensitivity * mouseMove.x;
        pitch += MouseSensitivity * mouseMove.y;
        pitch = Clamp(pitch, -90.0f, 90.0f);

        // Construct new orientation for the camera scene node from yaw and pitch. Roll is fixed to zero
        _cameraNode.rotation = Quaternion(pitch, yaw, 0.0f);

        if (console is null || !console.visible)
        {
            // Read WASD keys and move the camera scene node to the corresponding direction if they are pressed
            // Use the Translate() function (default local space) to move relative to the node's orientation.
            if (input.keyDown[KEY_W])
                _cameraNode.Translate(Vector3::FORWARD * FreeMoveSpeed * timeStep);
            if (input.keyDown[KEY_S])
                _cameraNode.Translate(Vector3::BACK * FreeMoveSpeed * timeStep);
            if (input.keyDown[KEY_A])
                _cameraNode.Translate(Vector3::LEFT * FreeMoveSpeed * timeStep);
            if (input.keyDown[KEY_D])
                _cameraNode.Translate(Vector3::RIGHT * FreeMoveSpeed * timeStep);
            if (input.keyDown[KEY_Q])
                _cameraNode.Translate(Vector3::UP * FreeMoveSpeed * timeStep);
            if (input.keyDown[KEY_E])
                _cameraNode.Translate(Vector3::DOWN * FreeMoveSpeed * timeStep);
        }
    }

}

class CamRigFstp : CamRig
{

    CamRigFstp(Scene@ scene, Node@ cameraNode)
    {
        super(scene, cameraNode);
    }

    void MoveCamera(float timeStep)
    {
    }

}

class CamRigThrdp : CamRig
{

    float CameraHeightAdjustStart = 1.0f;
    float CameraHeightAdjustEnd = 2.0f;
    bool AdjustingCameraHeight = false;

    CamRigThrdp(Scene@ scene, Node@ cameraNode)
    {
        super(scene, cameraNode);
    }

    void Init()
    {
        //~ _targetNode.AddChild(_cameraNode);
        UpdateCameraPosition(0.0f);
    }

    void UpdateCameraPosition(float timeStep)
    {
        // Ray cast ground
        Ray ray = Ray(_cameraNode.worldPosition, Vector3::DOWN);
        PhysicsRaycastResult[]@ result = physicsWorld.Raycast(ray, 10.0f);  // use mask!!!
        for (uint i = 0; i < result.length; i++)
        {
            if (result[i].body.node.name == "Terrain")
            {
                float height = _cameraNode.worldPosition.y - result[i].position.y;
                if (height < CameraHeightAdjustStart) {
                    AdjustingCameraHeight = true;
                } else if (AdjustingCameraHeight && height > CameraHeightAdjustEnd) {
                    AdjustingCameraHeight = false;
                }
            }
        }
        // Adjust pitch accoding to camera height
        if (AdjustingCameraHeight)
        {
            pitch += 50.0f * timeStep;
        }
        // Adjust camera position
        Quaternion dir(_targetNode.worldRotation.yaw, Vector3::UP);
        dir = dir * Quaternion(yaw, Vector3::UP);
        dir = dir * Quaternion(pitch, Vector3::RIGHT);
        _cameraNode.worldPosition = _targetNode.worldPosition - dir * Vector3(0.0f, 2.0f, 5.0f);
        _cameraNode.worldPosition += Vector3::UP * 2.0f;
        _cameraNode.LookAt(_targetNode.worldPosition + Vector3::UP * 1.5f);
    }

    void MoveCamera(float timeStep)
    {
        yaw += input.mouseMoveX * 0.1f;
        pitch += input.mouseMoveY * 0.1f;
        UpdateCameraPosition(timeStep);
    }

}

