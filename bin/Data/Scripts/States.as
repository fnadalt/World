#include "Constants.as"

class State
{

    String name;
    int id;

    State(String& name, int id)
    {
        this.name = name;
        this.id = id;
    }

    void Enter(State& prevState, VariantMap& data = VariantMap())
    {
        log.Info("Enter state '" + name + "'");
    }

    void Exit()
    {
        log.Info("Exit state '" + name + "'");
    }

}

class StateNull : State
{
    StateNull()
    {
        super("Null", APP_STATE_NULL);
    }
}
