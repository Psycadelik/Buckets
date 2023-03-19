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
      {KV.Registry, name: KV.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
