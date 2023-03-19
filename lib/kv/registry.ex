defmodule KV.Registry do
  use GenServer

  ## Client API
  @doc """
  Starts the registry

  - __MODULE__ means current module

  `name` is always required
  """
  def start_link(opts) do
    # 1. Pass the name to GenServer's init
    server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`

  Return `{:ok, pid}` if the bucket exists, `:error` otherwise
  """
  def lookup(server, name) do
    # 2. Lookup is now done directly in ETS, without accessing the server
    case :ets.lookup(server, name) do
      [{^name, pid}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Ensures there is a bucket associated with the given `name` in
  `server`
  """
  def create(server, name) do
    GenServer.call(server, {:create, name})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(table) do
    # 3. we have replaced the names map byt the ETS table
    names = :ets.new(table, [:named_table, read_concurrency: true])
    refs = %{}
    {:ok, {names, refs}}
  end

  @doc """
   - Call is one type of request you can send to a GenServer
   - They are synchronous i.e the server must send a response back to
   such requests
   - The client waits for a response
   - @impl true informs the compiler that our intention for the subsequent
   function definition is to define a callback

  - {:lookup, name} - the request
  - _from - the process from which we received the request
  - names - current server state

  handle_call returns a tuple in the following format {:reply, reply, new_state}
  - :reply - indicates that the server should send a reply back to the client
  - reply - what will be sent to the client
  - new_State - the new server state
  """
  @impl true
  def handle_call({:create, name}, _from, {names, refs}) do
    case lookup(names, name) do
      {:ok, pid} ->
        {:reply, pid, {names, refs}}

      :error ->
        {:ok, pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
        ref = Process.monitor(pid)
        refs = Map.put(refs, ref, name)
        :ets.insert(names, {name, pid})
        {:reply, pid, {names, refs}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    # 6. Delete from the ETS table instead of the map
    {name, refs} = Map.pop(refs, ref)
    :ets.delete(names, name)
    {:noreply, {names, refs}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
