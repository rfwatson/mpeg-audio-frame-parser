defmodule MPEGAudioFrameParserIntegrationTest do
  use ExUnit.Case

  test "128kbps 44100hz MP3" do
    MPEGAudioFrameParser.start_link()
    assert count_frames("test/fixtures/test_128_44100.mp3") == 254
  end

  test "64kbps 12000hz MP3" do
    MPEGAudioFrameParser.start_link()
    assert count_frames("test/fixtures/test_64_12000.mp3") == 140
  end

  test "160kbps 24000hz MP3" do
    MPEGAudioFrameParser.start_link()
    assert count_frames("test/fixtures/test_160_24000.mp3") == 277
  end

  test "128kbps 44100hz MP3 with CRC protection" do
    MPEGAudioFrameParser.start_link()
    assert count_frames("test/fixtures/test_128_44100_crc_protection.mp3") == 254
  end

  test "64kbps 22050hz MP2" do
    MPEGAudioFrameParser.start_link()
    assert count_frames("test/fixtures/test_64_22050.mp2") == 126
  end

  defp count_frames(path) do
    File.cwd!()
    |> Path.join(path)
    |> File.open!()
    |> read_bytes(4096, 0)
  end

  defp read_bytes(file, block_size, total_frames) do
    IO.binread(file, block_size)
    |> handle_read(file, block_size, total_frames)
  end

  defp handle_read(:eof, _file, _block_size, total_frames) do
    total_frames
  end

  defp handle_read(data, file, block_size, total_frames) do
    new_frames = MPEGAudioFrameParser.add_packet(data)
    read_bytes(file, block_size, total_frames + length(new_frames))
  end
end
