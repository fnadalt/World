#include <Urho3D/AngelScript/ScriptFile.h>
#include <Urho3D/AngelScript/Script.h>

#include <Urho3D/Core/Main.h>
#include <Urho3D/Engine/Engine.h>
#include <Urho3D/Engine/EngineDefs.h>
#include <Urho3D/IO/FileSystem.h>
#include <Urho3D/IO/Log.h>

#include <Urho3D/Resource/ResourceCache.h>
#include <Urho3D/Resource/ResourceEvents.h>

#include "World.h"

#include <Urho3D/DebugNew.h>

URHO3D_DEFINE_APPLICATION_MAIN(World);

World::World(Context* context) :
    Application(context),
    commandLineRead_(false)
{
}

void World::Setup()
{
    auto* filesystem = GetSubsystem<FileSystem>();
    const String commandFileName = filesystem->GetProgramDir() + "Data/CommandLine.txt";
    if (filesystem->FileExists(commandFileName))
    {
        SharedPtr<File> commandFile(new File(context_, commandFileName));
        if (commandFile->IsOpen())
        {
            commandLineRead_ = true;
            String commandLine = commandFile->ReadLine();
            commandFile->Close();
            ParseArguments(commandLine, false);
            engineParameters_ = Engine::ParseParameters(GetArguments());
        }
    }

    GetScriptFileName();

    engineParameters_[EP_LOG_NAME] = filesystem->GetAppPreferencesDir("urho3d", "logs") + GetFileNameAndExtension(scriptFileName_) + ".log";
    engineParameters_[EP_FULL_SCREEN]  = false;
    engineParameters_[EP_RESOURCE_PREFIX_PATHS] = ";";
    engineParameters_[EP_DUMP_SHADERS] = "shaders.txt";
}

void World::Start()
{
    context_->RegisterSubsystem(new Script(context_));
    scriptFile_ = GetSubsystem<ResourceCache>()->GetResource<ScriptFile>(scriptFileName_);

    if (scriptFile_ && scriptFile_->Execute("void Start()"))
    {
    } else {
        ErrorExit();
    }
}

void World::Stop()
{
    if (scriptFile_)
    {
        if (scriptFile_->GetFunction("void Stop()"))
            scriptFile_->Execute("void Stop()");
    }
}

void World::GetScriptFileName()
{
    const Vector<String>& arguments = GetArguments();
    if (arguments.Size() && arguments[0][0] != '-')
        scriptFileName_ = GetInternalPath(arguments[0]);
}
