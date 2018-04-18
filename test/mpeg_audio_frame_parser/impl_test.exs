defmodule MPEGAudioFrameParser.ImplTest do
  use ExUnit.Case

  # MP3, 128kbps, no CRC protection, 44100hz, no padding, stereo
  @frame1 <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 1::size(3304)>>
  @frame2 <<0b11111111111_11_01_0_1001_00_0_0_00_00_0_0_00::size(32), 0::size(3304)>>

  # MP3, 256kbps, no CRC protection, 48000hz, no padding, stereo
  @frame3 <<0b11111111111_11_01_0_1101_01_0_0_00_00_0_0_00::size(32), 1::size(6112)>>

  describe "add_packet" do
    import MPEGAudioFrameParser.Impl, only: [init: 0, add_packet: 2]

    test "handles a single frame at the start of a packet" do
      {:ok, state} = init()
      {:ok, state} = add_packet(state, @frame1)

      assert %{current_frame: nil, frames: [%{data: @frame1}]} = state
    end

    test "handles a single frame in the middle of a packet" do
      {:ok, state} = init()

      packet = <<0, 1, 2, 3, @frame1::binary>>
      {:ok, state} = add_packet(state, packet)

      assert %{current_frame: nil, frames: [%{data: @frame1}]} = state
    end

    test "ignores a packet that includes no valid frames at all" do
      {:ok, state} = init()

      {:ok, state} = add_packet(state, <<1::size(10240)>>)

      assert %{current_frame: nil, frames: []} = state
    end

    test "handles two frames in consecutive packets" do
      {:ok, state} = init()

      {:ok, state} = add_packet(state, @frame1)
      {:ok, state} = add_packet(state, @frame3)

      assert %{current_frame: nil, frames: [%{data: @frame3}, %{data: @frame1}]} = state
    end

    test "handles a frame split unevenly across consecutive packets" do
      {:ok, state} = init()

      part1 = :binary.part(@frame1, {0, 256})
      part2 = :binary.part(@frame1, {byte_size(@frame1), -(byte_size(@frame1) - 256)})

      {:ok, state} = add_packet(state, <<0, 1, 2, 3, part1::binary>>)
      {:ok, state} = add_packet(state, part2)

      assert length(state.frames) == 1
      assert List.first(state.frames).data == @frame1
    end

    test "handles three frames in a single packet" do
      {:ok, state} = init()
      {:ok, state} = add_packet(state, <<@frame1::binary, @frame1::binary, @frame1::binary>>)

      assert length(state.frames) == 3
      assert Enum.map(state.frames, & &1.data) == [@frame1, @frame1, @frame1]
    end

    test "handles three frames in consecutive packets" do
      {:ok, state} = init()
      {:ok, state} = add_packet(state, @frame3)
      {:ok, state} = add_packet(state, @frame3)
      {:ok, state} = add_packet(state, @frame3)

      assert length(state.frames) == 3
      assert Enum.map(state.frames, & &1.data) == [@frame3, @frame3, @frame3]
      assert is_nil(state.current_frame)
    end
  end

  describe "pop_frame" do
    import MPEGAudioFrameParser.Impl, only: [init: 0, add_packet: 2, pop_frame: 1]

    test "returns nil when there are no frames available" do
      {:ok, state} = init()

      assert pop_frame(state) == {:ok, nil, state}
    end

    test "returns a single frame" do
      {:ok, state} = init()

      {:ok, state} = add_packet(state, @frame1)
      {:ok, frame, state} = pop_frame(state)

      assert frame.data == @frame1
      assert state.frames == []
    end

    test "returns multiple frames in the correct order" do
      {:ok, state} = init()

      {:ok, state} = add_packet(state, @frame1)
      {:ok, state} = add_packet(state, @frame2)

      {:ok, frame, state} = pop_frame(state)
      assert frame.data == @frame1

      {:ok, frame, _state} = pop_frame(state)
      assert frame.data == @frame2
    end
  end
end
