defmodule MPEGAudioFrameParser do
  @moduledoc """
  This is the public API for MPEGAudioFrameParser application.

  MPEGAudioFrameParser is implemented as a GenServer that, when fed consecutive
  packets of binary data (for example, from a file or network source), will
  parse individual MPEG audio frames from the incoming data.

  No decoding is performed on the audio data. Instead, the resultant frames
  are ready to be fed into a separate decoder, or retransmitted over the
  network.
  """

  @server MPEGAudioFrameParser.Server

  @doc """
  Start the MPEG audio parser server. This must be done before calling the other
  API functions.

      iex> {:ok, pid} = MPEGAudioFrameParser.start_link()
      ...> is_pid(pid)
      true
  """
  def start_link(name \\ @server) do
    GenServer.start_link(@server, nil, name: name)
  end

  @doc """
  Add raw binary data to the current stream.

  Returns: A list of zero or more structs, each representing a complete MPEG
  audio frame. Note that because frames may be split across multiple packets,
  this list may be empty, or contain more than one frame on each call. Any
  leftover bytes will be stored by the server, and prepended to subsequent
  packets.

  ## Example

  Using a faked 128kbps 44.1k stereo MP3 frame:

      iex> packet = <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 1::size(3304)>>
      ...> {:ok, _pid} = MPEGAudioFrameParser.start_link()
      ...> MPEGAudioFrameParser.add_packet(packet)
      ...> MPEGAudioFrameParser.add_packet(packet)
      ...> |> length
      1

  """
  def add_packet(packet, name \\ @server) do
    GenServer.call(name, {:add_packet, packet})
  end

  @doc """
  Add raw binary data to the current stream.

  Similar to `MPEGAudioFrameParser.add_packet/1`, but does not return the
  frames. Instead, they can be retrieved at a later point, or by another
  process.

  See `MPEGAudioFrameParser.pop_frame/0`.
  """
  def cast_packet(packet, name \\ @server) do
    GenServer.cast(name, {:add_packet, packet})
  end

  @doc """
  Pop a single completed frame.
  Useful in combination with `MPEGAudioFrameParser.cast_packet/2`.

  Returns a struct representing an individual MPEG audio frame, or `nil` if no
  frame is available.

  ## Example

  Using a faked 128kbps 44.1k stereo MP3 frame:

      iex> packet = <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 1::size(3304)>>
      ...> {:ok, _pid} = MPEGAudioFrameParser.start_link()
      ...> MPEGAudioFrameParser.cast_packet(packet)
      :ok
      ...> MPEGAudioFrameParser.cast_packet(packet)
      :ok
      ...> frame = MPEGAudioFrameParser.pop_frame()
      ...> frame.__struct__
      MPEGAudioFrameParser.Frame
  """
  def pop_frame(name \\ @server) do
    GenServer.call(name, :pop_frame)
  end

  @doc """
  Reset the server's state, returning any available complete frames. Any
  additional bytes that are not part of a completed frame are discarded.

  Returns a list containing any available complete audio frames.
  """
  def flush(name \\ @server) do
    GenServer.call(name, :flush)
  end
end
