# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../create_notebooklm_notebooks'

class CreateNotebooklmTest < Minitest::Test
  # extract_answer calls String#force_encoding in place, so it expects the
  # mutable stdout that Open3 returns. Use unary plus to get mutable strings.
  def test_extract_answer_from_value_answer
    assert_equal 'the body', extract_answer(+'{"value":{"answer":"the body"}}')
  end

  def test_extract_answer_from_flat_answer
    assert_equal 'flat body', extract_answer(+'{"answer":"flat body"}')
  end

  def test_extract_answer_strips_surrounding_whitespace
    assert_equal 'padded', extract_answer(+'{"value":{"answer":"  padded  "}}')
  end

  def test_extract_answer_invalid_json_falls_back_to_raw
    assert_equal 'not json at all', extract_answer(+'  not json at all  ')
  end

  def test_extract_answer_missing_answer_returns_empty
    assert_equal '', extract_answer(+'{"value":{"other":1}}')
  end

  def test_thinking_frame_true_for_bold_prefix
    assert thinking_frame?('**Title** some draft')
  end

  def test_thinking_frame_false_for_plain_text
    refute thinking_frame?('タイトル: 本編')
  end

  def test_extract_notebook_id_parses_id_token
    assert_equal 'abc123', extract_notebook_id("Created notebook\nID: abc123\n")
  end

  def test_extract_notebook_id_nil_when_absent
    assert_nil extract_notebook_id('no id here')
  end
end
