#pragma once

#include <Urho3D/Engine/Application.h>

using namespace Urho3D;


class World : public Application
{
    URHO3D_OBJECT(World, Application);

public:

    explicit World(Context* context);

    void Setup() override;

    void Start() override;

    void Stop() override;

private:

    void GetScriptFileName();

    String scriptFileName_;
    bool commandLineRead_;

    SharedPtr<ScriptFile> scriptFile_;

};
