#include "Constants.as"

class Bomb : ScriptObject
{

    float Timeout = 5.0f;

    float _timer;

    void Start()
    {
        _timer = Timeout;
    }

    void Update(float timeStep)
    {
        _timer -= timeStep;
        if (_timer <= 0.0f)
        {
            BlowOff();
            node.Remove();
        }
    }

    void BlowOff()
    {
        Sphere sphere = Sphere(node.worldPosition, 10.0f);
        RigidBody@[]@ reachedBodies = physicsWorld.GetRigidBodies(sphere);
        log.Info("Got " + reachedBodies.length);
        for (uint i = 0; i < reachedBodies.length; i++)
        {
            RigidBody@ body = reachedBodies[i];
            Node@ bodyNode = body.node;
            log.Info("Blow " + bodyNode.name);
            Vector3 dir = bodyNode.position - node.position;
            float dist = dir.length;
            dir.Normalize();
            Vector3 impulse = dir * 100.0f / dist;
            body.ApplyImpulse(impulse);
            if (body.mass == 0.0f && bodyNode.HasTag(TAG_PROP) && impulse.length > 20.0f)
            {
                body.mass = 5.0f;
                body.friction = 1.0f;
                bodyNode.RemoveTag(TAG_PROP);
                bodyNode.AddTag(TAG_ITEM);
            }
        }
    }

}
