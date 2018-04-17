defmodule MPEGAudioFrameParser.Frame do
  defstruct version_id: nil,
            crc_protection: false,
            bitrate: nil,
            layer: nil,
            sample_rate: nil,
            padding: 0,
            channel_mode: nil,
            data: <<>>,
            valid: false,
            complete: false

  alias MPEGAudioFrameParser.Frame
  require Logger

  @sync_word 0b11111111111
  @header_length 32

  def from_header(header)
  when bit_size(header) == @header_length
  do
    frame = %Frame{data: header}
    |> Map.put(:version_id, parse_version(header))
    |> Map.put(:layer, parse_layer(header))
    |> Map.put(:crc_protection, parse_crc_protection(header))
    |> Map.put(:bitrate, parse_bitrate(header))
    |> Map.put(:sample_rate, parse_sample_rate(header))
    |> Map.put(:padding, parse_padding(header))

    %{frame | valid: header_valid?(frame)}
  end

  def header_valid?(%Frame{version_id: version_id, layer: layer, bitrate: bitrate, sample_rate: sample_rate})
  when version_id != :reserved
  and layer != :reserved
  and bitrate != :bad
  and sample_rate != :bad
  do
    true
  end

  def header_valid?(%Frame{}), do: false

  def frame_length(%Frame{bitrate: bitrate, sample_rate: sample_rate} = frame)
  when is_integer(bitrate)
  and is_integer(sample_rate)
  do
    bits_per_frame = samples_per_frame(frame) / 8
    (bits_per_frame * (frame.bitrate * 1000) / frame.sample_rate + frame.padding)
    |> trunc
  end

  def frame_length(%Frame{}), do: 0

  def add_bytes(frame, packet) do
    limit = bytes_missing(frame)
    {:ok, bytes, rest, complete} = split_packet(packet, limit)
    {:ok, %{frame | data: frame.data <> bytes, complete: complete}, rest}
  end

  def bytes_missing(frame) do
    (frame_length(frame) - byte_size(frame.data))
    |> max(0)
  end

  # Private Functions

  defp split_packet(packet, limit) do
    bytes_available = byte_size(packet)
    bytes_to_take = min(bytes_available, limit)
    bytes_to_leave = bytes_available - bytes_to_take

    part1 = :binary.part(packet, {0, bytes_to_take})
    part2 = :binary.part(packet, {bytes_available, -bytes_to_leave})

    {:ok, part1, part2, bytes_to_take == limit}
  end

  defp parse_version(<<@sync_word::size(11), bits::size(2), _::bits>>), do: version_atom(bits)

  defp version_atom(0b11), do: :version1
  defp version_atom(0b10), do: :version2
  defp version_atom(0b00), do: :"version2.5"
  defp version_atom(0b01), do: :reserved

  defp parse_layer(<<@sync_word::size(11), _::size(2), bits::size(2), _::bits>>), do: layer_atom(bits)

  defp layer_atom(0b11), do: :layer1
  defp layer_atom(0b10), do: :layer2
  defp layer_atom(0b01), do: :layer3
  defp layer_atom(0b00), do: :reserved

  defp parse_crc_protection(<<@sync_word::size(11), _::size(4), 0b0::size(1), _::bits>>), do: false
  defp parse_crc_protection(<<@sync_word::size(11), _::size(4), 0b1::size(1), _::bits>>), do: true

  defp parse_bitrate(<<@sync_word::size(11), version_bits::size(2), layer_bits::size(2), _::size(1), bitrate_bits::size(4), _::bits>>) do
    version_atom = version_atom(version_bits)
    layer_atom = layer_atom(layer_bits)

    case {version_atom, layer_atom, bitrate_bits} do
      # V1, L1
      {:version1, :layer1, 0b0001} -> 32
      {:version1, :layer1, 0b0010} -> 64
      {:version1, :layer1, 0b0011} -> 96
      {:version1, :layer1, 0b0100} -> 128
      {:version1, :layer1, 0b0101} -> 160
      {:version1, :layer1, 0b0110} -> 192
      {:version1, :layer1, 0b0111} -> 224
      {:version1, :layer1, 0b1000} -> 256
      {:version1, :layer1, 0b1001} -> 288
      {:version1, :layer1, 0b1010} -> 320
      {:version1, :layer1, 0b1011} -> 352
      {:version1, :layer1, 0b1100} -> 384
      {:version1, :layer1, 0b1101} -> 416
      {:version1, :layer1, 0b1110} -> 448

      # V1, L2
      {:version1, :layer2, 0b0001} -> 32
      {:version1, :layer2, 0b0010} -> 48
      {:version1, :layer2, 0b0011} -> 56
      {:version1, :layer2, 0b0100} -> 64
      {:version1, :layer2, 0b0101} -> 80
      {:version1, :layer2, 0b0110} -> 96
      {:version1, :layer2, 0b0111} -> 112
      {:version1, :layer2, 0b1000} -> 128
      {:version1, :layer2, 0b1001} -> 160
      {:version1, :layer2, 0b1010} -> 192
      {:version1, :layer2, 0b1011} -> 224
      {:version1, :layer2, 0b1100} -> 256
      {:version1, :layer2, 0b1101} -> 320
      {:version1, :layer2, 0b1110} -> 384

      # V1, L3
      {:version1, :layer3, 0b0001} -> 32
      {:version1, :layer3, 0b0010} -> 40
      {:version1, :layer3, 0b0011} -> 48
      {:version1, :layer3, 0b0100} -> 56
      {:version1, :layer3, 0b0101} -> 64
      {:version1, :layer3, 0b0110} -> 80
      {:version1, :layer3, 0b0111} -> 96
      {:version1, :layer3, 0b1000} -> 112
      {:version1, :layer3, 0b1001} -> 128
      {:version1, :layer3, 0b1010} -> 160
      {:version1, :layer3, 0b1011} -> 192
      {:version1, :layer3, 0b1100} -> 224
      {:version1, :layer3, 0b1101} -> 256
      {:version1, :layer3, 0b1110} -> 320

      # V2, L1
      {version, :layer1, 0b0001} when version in [:version2, :"version2.5"] -> 32
      {version, :layer1, 0b0010} when version in [:version2, :"version2.5"] -> 48
      {version, :layer1, 0b0011} when version in [:version2, :"version2.5"] -> 56
      {version, :layer1, 0b0100} when version in [:version2, :"version2.5"] -> 64
      {version, :layer1, 0b0101} when version in [:version2, :"version2.5"] -> 80
      {version, :layer1, 0b0110} when version in [:version2, :"version2.5"] -> 96
      {version, :layer1, 0b0111} when version in [:version2, :"version2.5"] -> 112
      {version, :layer1, 0b1000} when version in [:version2, :"version2.5"] -> 128
      {version, :layer1, 0b1001} when version in [:version2, :"version2.5"] -> 144
      {version, :layer1, 0b1010} when version in [:version2, :"version2.5"] -> 160
      {version, :layer1, 0b1011} when version in [:version2, :"version2.5"] -> 176
      {version, :layer1, 0b1100} when version in [:version2, :"version2.5"] -> 192
      {version, :layer1, 0b1101} when version in [:version2, :"version2.5"] -> 224
      {version, :layer1, 0b1110} when version in [:version2, :"version2.5"] -> 256

      # V2, L2/L3
      {version, _, 0b0001} when version in [:version2, :"version2.5"] -> 8
      {version, _, 0b0010} when version in [:version2, :"version2.5"] -> 16
      {version, _, 0b0011} when version in [:version2, :"version2.5"] -> 24
      {version, _, 0b0100} when version in [:version2, :"version2.5"] -> 32
      {version, _, 0b0101} when version in [:version2, :"version2.5"] -> 40
      {version, _, 0b0110} when version in [:version2, :"version2.5"] -> 48
      {version, _, 0b0111} when version in [:version2, :"version2.5"] -> 56
      {version, _, 0b1000} when version in [:version2, :"version2.5"] -> 64
      {version, _, 0b1001} when version in [:version2, :"version2.5"] -> 80
      {version, _, 0b1010} when version in [:version2, :"version2.5"] -> 96
      {version, _, 0b1011} when version in [:version2, :"version2.5"] -> 112
      {version, _, 0b1100} when version in [:version2, :"version2.5"] -> 128
      {version, _, 0b1101} when version in [:version2, :"version2.5"] -> 144
      {version, _, 0b1110} when version in [:version2, :"version2.5"] -> 160

      _ -> :bad
    end
  end

  defp parse_sample_rate(<<@sync_word::size(11), version_bits::size(2), _::size(7), sample_rate_bits::size(2), _::bits>>) do
    case {version_bits, sample_rate_bits} do
      {0b11, 0b00} -> 44100
      {0b11, 0b01} -> 48000
      {0b11, 0b10} -> 32000
      {0b10, 0b00} -> 22050
      {0b10, 0b01} -> 24000
      {0b10, 0b10} -> 16000
      {0b00, 0b00} -> 11025
      {0b00, 0b01} -> 12000
      {0b00, 0b10} -> 8000
      _ -> :bad
    end
  end

  defp parse_padding(<<@sync_word::size(11), _::size(11), 0b0::size(1), _::bits>>), do: 0
  defp parse_padding(<<@sync_word::size(11), _::size(11), 0b1::size(1), _::bits>>), do: 1

  defp samples_per_frame(%Frame{layer: :layer1}), do: 384
  defp samples_per_frame(%Frame{layer: :layer2}), do: 1152
  defp samples_per_frame(%Frame{layer: :layer3, version_id: :version1}), do: 1152
  defp samples_per_frame(%Frame{layer: :layer3, version_id: _}), do: 576
  defp samples_per_frame(%Frame{}), do: 0
end
