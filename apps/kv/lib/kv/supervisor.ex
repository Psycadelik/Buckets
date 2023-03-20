defmodule KV.Supervisor do
  use Supervisor

  @doc """
  - :one_for_one supervision strategy means that if a child dies, it will be the
  only one restarted
  - once supervisor starts, it traverses the list of children invoking child_spec/1
  function on each module
  - 
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      # add a dynamic supervisor as a child
      # NB: we end up with a supervision tree when we begin supervisors
      # that supervise other supervisors
      {DynamicSupervisor, name: KV.BucketSupervisor, strategy: :one_for_one},
      {KV.Registry, name: KV.Registry}
    ]

    # :one_for_all strategy - the supervisor will kill and restart all of its
    # children processes whenever any one of them dies
    Supervisor.init(children, strategy: :one_for_all)
  end
end
