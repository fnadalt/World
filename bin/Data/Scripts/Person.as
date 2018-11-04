#include "Constants.as"

// States
const int MAN_STATE_NULL = 0;
const int MAN_STATE_IDLE = 1;
const int MAN_STATE_WALK = 2;
const int MAN_STATE_RUN = 3;
const int MAN_STATE_JUMP = 4;
const int MAN_STATE_FALL = 5;
const int MAN_STATE_GRAB = 6;

//
const float MOVE_FORCE = 0.8f;
const float INAIR_MOVE_FORCE = 0.02f;
const float BRAKE_FORCE = 0.2f;
const float JUMP_FORCE = 7.0f;
const float INAIR_THRESHOLD_TIME = 0.15f;


class Person : ScriptObject
{

    RigidBody@ body;
    AnimationController@ animCtrl;

    //  controls.
    Controls controls;
    Controls prevControls;
    // Grounded flag for movement.
    bool _onGround = false;
    // Jump flag.
    bool _okToJump = true;
    // In air timer. Due to possible physics inaccuracy,  can be off ground for max. 1/10 second and still be allowed to move.
    float _inAirTimer = 0.0f;

    // Grabbed node
    Node@ handNode;
    Node@ grabbedNode;


    void Start()
    {
        log.Info("Man::Start id=" + String(node.id));
        //
        node.vars["yaw"] = node.rotation.yaw;
        node.vars["pitch"] = node.rotation.pitch;
        //
        SubscribeToEvent(node, "NodeCollision", "HandleNodeCollision");
    }

    void DelayedStart()
    {
        log.Info("Man::DelayedStart id=" + String(node.id));
        //
        animCtrl = cast<AnimationController>(node.GetComponent("AnimationController", true));
        //
        body = cast<RigidBody>(node.GetComponent("RigidBody"));
        handNode = node.GetChild("hand.R", true);
        if (handNode.numChildren == 1)  // has sthg grabbed
        {
            grabbedNode = handNode.children[0];
            log.Info("Found grabbed node by : " + grabbedNode.name);
        }
    }

    void Stop()
    {
        log.Info("Man::Stop");
        //
        animCtrl = null;
        body = null;
        handNode = null;
        grabbedNode = null;
    }

    void Load(Deserializer& deserializer)
    {
        controls.yaw = deserializer.ReadFloat();
        controls.pitch = deserializer.ReadFloat();
    }

    void Save(Serializer& serializer)
    {
        serializer.WriteFloat(controls.yaw);
        serializer.WriteFloat(controls.pitch);
    }

    void HandleNodeCollision(StringHash eventType, VariantMap& eventData)
    {
        VectorBuffer contacts = eventData["Contacts"].GetBuffer();

        while (!contacts.eof)
        {
            Vector3 contactPosition = contacts.ReadVector3();
            Vector3 contactNormal = contacts.ReadVector3();
            float contactDistance = contacts.ReadFloat();
            float contactImpulse = contacts.ReadFloat();

            // If contact is below node center and pointing up, assume it's a ground contact
            if (contactPosition.y < (node.position.y + 1.0f))
            {
                float level = contactNormal.y;
                if (level > 0.75)
                    _onGround = true;
            }

        }
    }

    void Update(float timeStamp)
    {
        // Controls
        prevControls = controls;
        controls.Set(CTRL_ALL, false);
        controls.buttons = node.vars["buttons"].GetInt();
        controls.yaw = node.vars["yaw"].GetFloat();
        controls.pitch = node.vars["pitch"].GetFloat();

        //
        if (controls.IsPressed(CTRL_PICK, prevControls))
        {
            if (grabbedNode is null)
            // Pick?
            {
                // Items contacted?
                RigidBody@[]@ collBodies = physicsWorld.GetCollidingBodies(body);
                for (uint i = 0; i < collBodies.length; i++)
                {
                    if (collBodies[i].node.HasTag(TAG_ITEM))
                    {
                        // Pick
                        grabbedNode = collBodies[i].node;
                        collBodies[i].enabled = false;
                        break;
                    }
                }
                //~ grabbedNode.parent = handNode;
                //~ grabbedNode.position = Vector3::ZERO;
                //~ grabbedNode.rotation = Quaternion(0.0f, 0.0f, 0.0f);
            }
            else
            // Drop
            {
                //~ grabbedNode.parent = scene;
                //~ grabbedNode.position += Vector3::FORWARD * 2.0f;
                //~ grabbedNode.rotation = Quaternion(0.0f, 0.0f, 0.0f);
                RigidBody@ grabbedBody = cast<RigidBody>(grabbedNode.GetComponent("RigidBody"));
                grabbedBody.enabled = true;
                grabbedNode = null;
            }
        }

        //
        if (controls.IsPressed(CTRL_ACTION, prevControls))
        {
            Vector3 position = node.position + node.direction * 1.0f + Vector3::UP * 0.75f;
            Quaternion rotation = Quaternion(0.0f, 0.0f, 0.0f);
            Node@ bomb = scene.InstantiateXML(cache.GetFile("Objects/Bomb.xml"), position, rotation);
        }
    }

    void FixedUpdate(float timeStep)
    {
        // Update the in air timer. Reset if grounded
        if (!_onGround)
            _inAirTimer += timeStep;
        else
            _inAirTimer = 0.0f;
        // When  has been in air less than 1/10 second, it's still interpreted as being on ground
        bool softGrounded = _inAirTimer < INAIR_THRESHOLD_TIME;

        // Update movement & animation
        Quaternion rot = node.rotation;
        Vector3 moveDir(0.0f, 0.0f, 0.0f);
        Vector3 velocity = body.linearVelocity;
        // Velocity on the XZ plane
        Vector3 planeVelocity(velocity.x, 0.0f, velocity.z);

        if (controls.IsDown(CTRL_FORWARD))
            moveDir += Vector3::FORWARD;
        if (controls.IsDown(CTRL_BACK))
            moveDir += Vector3::BACK;
        if (controls.IsDown(CTRL_LEFT))
            moveDir += Vector3::LEFT;
        if (controls.IsDown(CTRL_RIGHT))
            moveDir += Vector3::RIGHT;

        // Normalize move vector so that diagonal strafing is not faster
        if (moveDir.lengthSquared > 0.0f)
            moveDir.Normalize();

        // If in air, allow control, but slower than when on ground
        body.ApplyImpulse(rot * moveDir * (softGrounded ? MOVE_FORCE : INAIR_MOVE_FORCE));

        node.rotation = Quaternion(controls.yaw, Vector3::UP);

        if (softGrounded)
        {
            // When on ground, apply a braking force to limit maximum ground velocity
            Vector3 brakeForce = -planeVelocity * BRAKE_FORCE;
            body.ApplyImpulse(brakeForce);

            // Jump. Must release jump control between jumps
            if (controls.IsDown(CTRL_JUMP))
            {
                if (_okToJump)
                {
                    body.ApplyImpulse(Vector3::UP * JUMP_FORCE);
                    _okToJump = false;
                    animCtrl.SetStartBone(node.name + "/Models/saltar.ani", "main");
                    animCtrl.PlayExclusive(node.name + "/Models/saltar.ani", 0, false, 0.2f);
                    animCtrl.SetSpeed(node.name + "/Models/saltar.ani", body.linearVelocity.y * 0.05f);
                }
            }
            else
                _okToJump = true;
        }

        //~ debugHud.SetAppStats("_onGround", String(_onGround));
        if (!_onGround)
        {
            animCtrl.SetStartBone(node.name + "/Models/saltar.ani", "main");
            animCtrl.PlayExclusive(node.name + "/Models/saltar.ani", 0, false, 0.2f);
            animCtrl.SetSpeed(node.name + "/Models/saltar.ani", body.linearVelocity.y * 0.05f);
        }
        else
        {
            // Play walk animation if moving on ground, otherwise fade it out
            if (softGrounded && !moveDir.Equals(Vector3::ZERO))
            {
                //~ debugHud.SetAppStats("animCntrl", "correr");
                animCtrl.SetStartBone(node.name + "/Models/correr.ani", "main");
                //~ animCtrl.SetWeight(node.name + "/Models/correr.ani", 1.0f);
                animCtrl.PlayExclusive(node.name + "/Models/correr.ani", 0, true, 0.2f);
                // Set walk animation speed proportional to velocity
                animCtrl.SetSpeed(node.name + "/Models/correr.ani", planeVelocity.length * 0.3f);
            }
            else
            {
                //~ debugHud.SetAppStats("animCntrl", "quieto");
                animCtrl.SetStartBone(node.name + "/Models/quieto.ani", "main");
                animCtrl.PlayExclusive(node.name + "/Models/quieto.ani", 0, true, 0.2f);
            }

        }

        // Reset grounded flag for next frame
        _onGround = false;

        // Update grabbed node transform, expensive?! Torpid at least.
        if (grabbedNode !is null)
        {
            grabbedNode.worldPosition = handNode.worldPosition;
            grabbedNode.worldRotation = handNode.worldRotation * Quaternion(90.0f, Vector3::FORWARD);
        }

    }

}
