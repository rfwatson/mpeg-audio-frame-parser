defmodule MPEGAudioFrameParser.Server do
  use GenServer
  alias MPEGAudioFrameParser.Impl
  require IEx

  def init(_args), do: Impl.init()

  def handle_call({:add_packet, packet}, _from, state) do
    {:ok, state} = Impl.add_packet(state, packet)
    {:reply, state.frames, %{state | frames: []}}
  end

  def handle_call(:pop_frame, _from, state) do
    {:ok, frame, new_state} = Impl.pop_frame(state)
    {:reply, frame, new_state}
  end

  def handle_call(:flush, _from, state) do
    {:ok, frames, new_state} = Impl.flush(state)
    {:reply, frames, new_state}
  end

  def handle_cast({:add_packet, packet}, state) do
    {:ok, state} = Impl.add_packet(state, packet)
    {:noreply, state}
  end
end
