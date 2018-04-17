defmodule MPEGAudioFrameParserTest do
  use ExUnit.Case
  alias MPEGAudioFrameParser.Frame
  doctest MPEGAudioFrameParser

  # MP3, 128kbps, no CRC protection, 44100hz, no padding, stereo
  @frame1 <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 1::size(3304)>>
  @frame2 <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 0::size(3304)>>

  test "start_link" do
    MPEGAudioFrameParser.start_link()
  end

  test "add_packet" do
    MPEGAudioFrameParser.start_link()
    MPEGAudioFrameParser.add_packet(@frame1)
    result = MPEGAudioFrameParser.add_packet(@frame2)

    assert [%Frame{data: @frame1}] = result
  end

  test "cast_packet" do
    MPEGAudioFrameParser.start_link()
    MPEGAudioFrameParser.cast_packet(@frame1)
    MPEGAudioFrameParser.cast_packet(@frame2)
  end

  test "pop_frame" do
    MPEGAudioFrameParser.start_link()
    MPEGAudioFrameParser.cast_packet(@frame1)
    MPEGAudioFrameParser.cast_packet(@frame2)

    assert %Frame{data: @frame1} = MPEGAudioFrameParser.pop_frame()
    assert nil == MPEGAudioFrameParser.pop_frame()
  end

  test "flush" do
    MPEGAudioFrameParser.start_link()
    MPEGAudioFrameParser.cast_packet(@frame1)
    MPEGAudioFrameParser.cast_packet(@frame2)
    MPEGAudioFrameParser.flush()

    assert nil == MPEGAudioFrameParser.pop_frame()
  end
end
