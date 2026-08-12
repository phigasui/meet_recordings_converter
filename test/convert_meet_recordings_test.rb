# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'

# Loadable as a library: the script guards main with __FILE__ == $PROGRAM_NAME.
require_relative '../convert_meet_recordings'

class ConvertMeetRecordingsTest < Minitest::Test
  def test_generate_output_path_swaps_extension
    assert_equal '/out/video.mp3', generate_output_path('/in/video.mp4', '/out')
  end

  def test_generate_output_path_keeps_tricky_basename
    assert_equal '/out/He said hi 12:30.mp3',
                 generate_output_path('/in/He said hi 12:30.mkv', '/out')
  end

  def test_generate_output_path_strips_only_last_extension
    # File.basename(name, '.*') removes a single trailing extension.
    assert_equal '/out/2026.01.02.mp3', generate_output_path('/in/2026.01.02.mp4', '/out')
  end

  def test_skip_chat_file_true_for_chat
    silence_stdout { assert skip_chat_file?('Meeting Chat.txt') }
  end

  def test_skip_chat_file_false_otherwise
    refute skip_chat_file?('Recording.mp4')
  end

  private

  def silence_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end
end
