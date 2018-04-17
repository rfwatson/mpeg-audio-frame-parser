defmodule MPEGAudioFrameParser.FrameTest do
  use ExUnit.Case
  alias MPEGAudioFrameParser.Frame
  import Frame, only: [from_header: 1, header_valid?: 1, frame_length: 1, bytes_missing: 1]

  # MP3, 128kbps, no CRC protection, 44100hz, no padding, stereo
  @header1 <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32)>>

  # MP3, 256kbps, no CRC protection, 48000hz, no padding, stereo
  @header2 <<0b11111111111_11_01_0_1101_01_0_0_00_00_0_0_00::size(32)>>

  # MP3, 32kbps, no CRC protection, 22050hz, padding, stereo
  @header3 <<0b11111111111_10_01_0_0100_00_1_0_00_00_0_0_00::size(32)>>

  # MP2, 256kbps, no CRC protection, 44100hz, no padding, stereo
  @header4 <<0b11111111111_11_10_0_1100_00_0_0_00_00_0_0_00::size(32)>>

  # MP1, 192kbps, no CRC protection, 44100hz, no padding, stereo
  @header5 <<0b11111111111_11_11_0_0110_00_0_0_00_00_0_0_00::size(32)>>

  # MP3, 40kbps, CRC protection, 8000hz, no padding, stereo
  @header6 <<0b11111111111_00_01_1_0101_10_0_0_00_00_0_0_00::size(32)>>

  # Invalid header, reserved version bit set
  @header7 <<0b11111111111_01_01_0_1001_00_0_0_00_00_0_0_00::size(32)>>

  test "parsing version ID" do
    assert from_header(@header1).version_id == :version1
    assert from_header(@header2).version_id == :version1
    assert from_header(@header3).version_id == :version2
    assert from_header(@header4).version_id == :version1
    assert from_header(@header5).version_id == :version1
    assert from_header(@header6).version_id == :"version2.5"
    assert from_header(@header7).version_id == :reserved
  end

  test "parsing layer description" do
    assert from_header(@header1).layer == :layer3
    assert from_header(@header2).layer == :layer3
    assert from_header(@header3).layer == :layer3
    assert from_header(@header4).layer == :layer2
    assert from_header(@header5).layer == :layer1
    assert from_header(@header6).layer == :layer3
  end

  test "parsing CRC protection bit" do
    refute from_header(@header1).crc_protection
    refute from_header(@header2).crc_protection
    refute from_header(@header3).crc_protection
    refute from_header(@header4).crc_protection
    refute from_header(@header5).crc_protection
    assert from_header(@header6).crc_protection
  end

  test "parsing bitrate" do
    assert from_header(@header1).bitrate == 128
    assert from_header(@header2).bitrate == 256
    assert from_header(@header3).bitrate == 32
    assert from_header(@header4).bitrate == 256
    assert from_header(@header5).bitrate == 192
    assert from_header(@header6).bitrate == 40
  end

  test "parsing sample rate" do
    assert from_header(@header1).sample_rate == 44100
    assert from_header(@header2).sample_rate == 48000
    assert from_header(@header3).sample_rate == 22050
    assert from_header(@header4).sample_rate == 44100
    assert from_header(@header5).sample_rate == 44100
    assert from_header(@header6).sample_rate == 8000
  end

  test "parsing padding" do
    assert from_header(@header1).padding == 0
    assert from_header(@header2).padding == 0
    assert from_header(@header3).padding == 1
    assert from_header(@header4).padding == 0
    assert from_header(@header5).padding == 0
    assert from_header(@header6).padding == 0
  end

  test "header validity" do
    assert from_header(@header1) |> header_valid?
    assert from_header(@header2) |> header_valid?
    assert from_header(@header3) |> header_valid?
    assert from_header(@header4) |> header_valid?
    assert from_header(@header5) |> header_valid?
    assert from_header(@header6) |> header_valid?
    refute from_header(@header7) |> header_valid?
  end

  test "frame_length" do
    assert from_header(@header1) |> frame_length == 417
    assert from_header(@header2) |> frame_length == 768
    assert from_header(@header3) |> frame_length == 105
    assert from_header(@header4) |> frame_length == 835
    assert from_header(@header5) |> frame_length == 208
    assert from_header(@header6) |> frame_length == 360
  end

  test "bytes missing" do
    assert from_header(@header1) |> bytes_missing == 413
  end
end
