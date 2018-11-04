#include "Constants.as"

// Vehicle script object class
//
// When saving, the node and component handles are automatically converted into nodeID or componentID attributes
// and are acquired from the scene when loading. The steering member variable will likewise be saved automatically.
// The Controls object can not be automatically saved, so handle it manually in the Load() and Save() methods

const float ENGINE_POWER = 10.0f;
const float DOWN_FORCE = 10.0f;
const float MAX_WHEEL_ANGLE = 22.5f;

class Vehicle : ScriptObject
{
    Node@ frontLeft;
    Node@ frontRight;
    Node@ rearLeft;
    Node@ rearRight;
    Constraint@ frontLeftAxis;
    Constraint@ frontRightAxis;
    RigidBody@ hullBody;
    RigidBody@ frontLeftBody;
    RigidBody@ frontRightBody;
    RigidBody@ rearLeftBody;
    RigidBody@ rearRightBody;

    // Current left/right steering amount (-1 to 1.)
    float steering = 0.0f;
    // Vehicle controls.
    Controls controls;

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

    void Init()
    {

        Node@ model = node.CreateChild("Model");

        // This function is called only from the main program when initially creating the vehicle, not on scene load
        StaticModel@ hullObject = node.CreateComponent("StaticModel");
        hullBody = node.CreateComponent("RigidBody", LOCAL);
        CollisionShape@ hullShape = node.CreateComponent("CollisionShape", LOCAL);

        node.scale = Vector3(1.5f, 1.0f, 3.0f);
        hullObject.model = cache.GetResource("Model", "Models/Box.mdl");
        hullObject.material = cache.GetResource("Material", "Materials/Stone.xml");
        hullObject.castShadows = true;
        hullShape.SetBox(Vector3::ONE);
        hullBody.mass = 4.0f;
        hullBody.friction = 10.0f;
        hullBody.linearDamping = 0.2f; // Some air resistance
        hullBody.angularDamping = 0.5f;
        hullBody.collisionLayer = 1;

        frontLeft = InitWheel("FrontLeft", Vector3(-0.6f, -0.4f, 0.3f));
        frontRight = InitWheel("FrontRight", Vector3(0.6f, -0.4f, 0.3f));
        rearLeft = InitWheel("RearLeft", Vector3(-0.6f, -0.4f, -0.3f));
        rearRight = InitWheel("RearRight", Vector3(0.6f, -0.4f, -0.3f));

        frontLeftAxis = frontLeft.GetComponent("Constraint");
        frontRightAxis = frontRight.GetComponent("Constraint");
        frontLeftBody = frontLeft.GetComponent("RigidBody");
        frontRightBody = frontRight.GetComponent("RigidBody");
        rearLeftBody = rearLeft.GetComponent("RigidBody");
        rearRightBody = rearRight.GetComponent("RigidBody");
    }

    Node@ InitWheel(const String&in name, const Vector3&in offset)
    {
        // Note: do not parent the wheel to the hull scene node. Instead create it on the root level and let the physics
        // constraint keep it together
        Node@ wheelNode = scene.CreateChild(name);
        wheelNode.position = node.LocalToWorld(offset);
        wheelNode.rotation = node.worldRotation * (offset.x >= 0.0f ? Quaternion(0.0f, 0.0f, -90.0f) :
            Quaternion(0.0f, 0.0f, 90.0f));
        wheelNode.scale = Vector3(0.8f, 0.5f, 0.8f);

        StaticModel@ wheelObject = wheelNode.CreateComponent("StaticModel");
        RigidBody@ wheelBody = wheelNode.CreateComponent("RigidBody", LOCAL);
        CollisionShape@ wheelShape = wheelNode.CreateComponent("CollisionShape", LOCAL);
        Constraint@ wheelConstraint = wheelNode.CreateComponent("Constraint", LOCAL);

        wheelObject.model = cache.GetResource("Model", "Models/Cylinder.mdl");
        wheelObject.material = cache.GetResource("Material", "Materials/Stone.xml");
        wheelObject.castShadows = true;
        wheelShape.SetSphere(1.0f);
        wheelBody.friction = 1;
        wheelBody.mass = 1;
        wheelBody.linearDamping = 0.2f; // Some air resistance
        wheelBody.angularDamping = 0.75f; // Could also use rolling friction
        wheelBody.collisionLayer = 1;
        wheelConstraint.constraintType = CONSTRAINT_HINGE;
        wheelConstraint.otherBody = node.GetComponent("RigidBody");
        wheelConstraint.worldPosition = wheelNode.worldPosition; // Set constraint's both ends at wheel's location
        wheelConstraint.axis = Vector3::UP; // Wheel rotates around its local Y-axis
        wheelConstraint.otherAxis = offset.x >= 0.0f ? Vector3::RIGHT : Vector3::LEFT; // Wheel's hull axis points either left or right
        wheelConstraint.lowLimit = Vector2(-180.0f, 0.0f); // Let the wheel rotate freely around the axis
        wheelConstraint.highLimit = Vector2(180.0f, 0.0f);
        wheelConstraint.disableCollision = true; // Let the wheel intersect the vehicle hull

        return wheelNode;
    }

    void Update(float timeStep)
    {
        controls.Set(CTRL_ALL, false);
        controls.buttons = node.vars["buttons"].GetInt();
        controls.yaw = node.vars["yaw"].GetFloat();
        controls.pitch = node.vars["pitch"].GetFloat();
    }

    void FixedUpdate(float timeStep)
    {
        float newSteering = 0.0f;
        float accelerator = 0.0f;

        if (controls.IsDown(CTRL_LEFT))
            newSteering = -1.0f;
        if (controls.IsDown(CTRL_RIGHT))
            newSteering = 1.0f;
        if (controls.IsDown(CTRL_FORWARD))
            accelerator = 1.0f;
        if (controls.IsDown(CTRL_BACK))
            accelerator = -0.5f;

        // When steering, wake up the wheel rigidbodies so that their orientation is updated
        if (newSteering != 0.0f)
        {
            frontLeftBody.Activate();
            frontRightBody.Activate();
            steering = steering * 0.95f + newSteering * 0.05f;
        }
        else
            steering = steering * 0.8f + newSteering * 0.2f;

        Quaternion steeringRot(0.0f, steering * MAX_WHEEL_ANGLE, 0.0f);

        frontLeftAxis.otherAxis = steeringRot * Vector3::LEFT;
        frontRightAxis.otherAxis = steeringRot * Vector3::RIGHT;

        if (accelerator != 0.0f)
        {
            // Torques are applied in world space, so need to take the vehicle & wheel rotation into account
            Vector3 torqueVec = Vector3(ENGINE_POWER * accelerator, 0.0f, 0.0f);

            frontLeftBody.ApplyTorque(node.rotation * steeringRot * torqueVec);
            frontRightBody.ApplyTorque(node.rotation * steeringRot * torqueVec);
            rearLeftBody.ApplyTorque(node.rotation * torqueVec);
            rearRightBody.ApplyTorque(node.rotation * torqueVec);
        }

        // Apply downforce proportional to velocity
        Vector3 localVelocity = hullBody.rotation.Inverse() * hullBody.linearVelocity;
        hullBody.ApplyForce(hullBody.rotation * Vector3::DOWN * Abs(localVelocity.z) * DOWN_FORCE);
    }
}

