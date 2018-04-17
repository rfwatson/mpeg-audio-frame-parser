defmodule MPEGAudioFrameParser.Impl do
  alias MPEGAudioFrameParser.Frame
  require Logger

  @sync_word 0b11111111111
  @initial_state %{leftover: <<>>, current_frame: nil, frames: []}

  def init() do
    {:ok, @initial_state}
  end

  def add_packet(state, packet) do
    process_bytes(state, packet)
  end

  def pop_frame(%{frames: []} = state) do
    {:ok, nil, state}
  end

  def pop_frame(state) do
    {frame, rest} = List.pop_at(state.frames, -1)
    {:ok, frame, %{state | frames: rest}}
  end

  def flush(state) do
    {:ok, state.frames, @initial_state}
  end

  # Private Functions

  # No data left, or not enough to be able to validate next frame. Return:
  defp process_bytes(state, packet)
  when bit_size(packet) < 32
  do
    {:ok, %{state | leftover: packet}}
  end

  # Leftover from previous call available. Prepend to this packet:
  defp process_bytes(%{leftover: leftover} = state, packet)
  when bit_size(leftover) > 0
  do
    process_bytes(%{state | leftover: <<>>}, <<leftover::bits, packet::bits>>)
  end

  # Not synced, found a sync word. Create a new frame struct:
  defp process_bytes(%{current_frame: nil} = state, <<@sync_word::size(11), header::size(21), rest::bits>>) do
    header = <<@sync_word::size(11), header::size(21)>>
    frame = Frame.from_header(header)
    process_bytes(%{state | current_frame: frame}, rest)
  end

  # Not synced, no sync word found. Discard a byte:
  defp process_bytes(%{current_frame: nil} = state, packet) do
    <<_byte, rest::bits>> = packet
    process_bytes(state, rest)
  end

  # Synced, but with an invalid header. Discard a byte:
  defp process_bytes(%{current_frame: %Frame{valid: false}} = state, packet) do
    data = <<state.current_frame.data, packet::bits>>
    <<_byte, rest::bits>> = data
    process_bytes(%{state | current_frame: nil}, rest)
  end

  # Synced, frame complete, and looks like another sync word. Create a new frame struct:
  defp process_bytes(%{current_frame: %Frame{complete: true}} = state, <<@sync_word::size(11), header::size(21), rest::bits>>) do
    header = <<@sync_word::size(11), header::size(21)>>
    frames = [state.current_frame | state.frames]
    new_state = %{state | current_frame: Frame.from_header(header), frames: frames}
    process_bytes(new_state, rest)
  end

  # Synced, frame complete, but next frame looks bad. Prepend, discard a byte and unsync:
  defp process_bytes(%{current_frame: %Frame{complete: true}} = state, packet) do
    Logger.warn "Lost sync. Discarding a byte and searching again for a sync word."
    <<_byte, rest>> = state.current_frame.data
    process_bytes(%{state | current_frame: nil}, <<rest, packet::bits>>)
  end

  # Synced, current frame not complete and we have bytes available. Add bytes to frame:
  defp process_bytes(%{current_frame: %Frame{complete: false}} = state, packet) do
    {:ok, frame, rest} = Frame.add_bytes(state.current_frame, packet)
    process_bytes(%{state | current_frame: frame}, rest)
  end
end
