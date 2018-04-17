defmodule MPEGAudioFrameParser.Example do
  require Logger

  def run(path_to_mp3, block_size \\ 2048) do
    # start our test process:
    MPEGAudioFrameParser.start_link()

    # open the provided file:
    {:ok, file} = File.open(path_to_mp3, [:read, :binary])

    # and start to read blocks of data:
    read_bytes(file, block_size, 0, 0, 0)
  end

  defp read_bytes(file, block_size, total_packets, total_frames, total_bytes_processed) do
    IO.binread(file, block_size)
    |> handle_read(file, block_size, total_packets + 1, total_frames, total_bytes_processed)
  end

  defp handle_read(:eof, _file, _block_size, total_packets, total_frames, total_bytes_processed) do
    Logger.info(
      "End of file detected. Parsed #{total_frames} MP3 frames from #{total_packets} packets of data, total bytes processed #{
        total_bytes_processed
      }"
    )
  end

  defp handle_read(
         {:error, reason},
         _file,
         _block_size,
         _total_packets,
         _total_frames,
         _total_bytes_processed
       ) do
    Logger.error("Error reading file: #{reason}")
    exit(:shutdown)
  end

  defp handle_read(data, file, block_size, total_packets, total_frames, total_bytes_processed) do
    frames = MPEGAudioFrameParser.add_packet(data)
    check_frames(frames)

    read_bytes(
      file,
      block_size,
      total_packets,
      total_frames + length(frames),
      total_byte_size(frames, total_bytes_processed)
    )
  end

  defp check_frames([]), do: nil

  defp check_frames(frames) do
    [head | tail] = frames
    print_frame(head)
    check_frames(tail)
  end

  defp print_frame(_frame) do
  end

  defp total_byte_size([], total), do: total

  defp total_byte_size(list, total) do
    [head | tail] = list
    total_byte_size(tail, total + byte_size(head.data))
  end
end
