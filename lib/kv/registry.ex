defmodule KV.Registry do
  use GenServer

  ## Client API
  @doc """
  Starts the registry

  - __MODULE__ means current module
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`

  Return `{:ok, pid}` if the bucket exists, `:error` otherwise
  """
  def lookup(server, name) do
    GenServer.call(server, {:lookup, name})
  end

  @doc """
  Ensures there is a bucket associated with the given `name` in
  `server`
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    names = %{}
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
  def handle_call({:lookup, name}, _from, state) do
    {names, _} = state
    {:reply, Map.fetch(names, name), state}
  end

  @doc """
  - Cast is another type of request you can send to a GenServer
  - They are asynchronous i.e the server won't send a response back
  - The client doesn't wait for a response

  - {:create, name} - request
  - names - current server state

  handle_cast returns a tuple in the format {:noreply, new_state}
  """
  @impl true
  def handle_cast({:create, name}, {names, refs}) do
    if Map.has_key?(names, name) do
      {:noreply, {names, refs}}
    else
      {:ok, pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
      ref = Process.monitor(pid)
      refs = Map.put(refs, ref, name)
      names = Map.put(names, name, pid)
      {:noreply, {names, refs}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    names = Map.delete(names, name)
    {:noreply, {names, refs}}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in KV.Registry: #{inspect(msg)}")
    {:noreply, state}
  end
end
