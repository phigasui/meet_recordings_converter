# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'time'
require_relative '../publish_to_spotify'

class PublishToSpotifyTest < Minitest::Test
  FIXTURES = File.join(__dir__, 'fixtures')

  # nlm escape normalization now lives in PodcastToolkit::Nlm; see
  # podcast_toolkit_nlm_test.rb for its contract tests.

  # ---- citation stripping & metadata parsing ----

  def test_strip_citations_removes_various_markers
    assert_equal 'Hello world end.', strip_citations('Hello [1] world [2, 3] end [4-6].')
  end

  def test_parse_metadata_happy_path
    result = parse_metadata("タイトル: My Title\n\n説明: A description here.")
    assert_equal 'My Title', result[:title]
    assert_equal 'A description here.', result[:description]
  end

  def test_parse_metadata_fullwidth_colon_and_citations
    result = parse_metadata("タイトル：全角 [1]\n\n説明：本文です。")
    assert_equal '全角', result[:title]
    assert_equal '本文です。', result[:description]
  end

  def test_parse_metadata_returns_nil_for_bad_format
    assert_nil parse_metadata('no recognizable format')
  end

  def test_parse_metadata_returns_nil_for_nil
    assert_nil parse_metadata(nil)
  end

  # ---- duration & schedule ----

  def test_format_duration
    assert_equal '01:01:01', format_duration(3661)
    assert_equal '00:00:59', format_duration(59)
    assert_equal '00:00:00', format_duration(0)
  end

  def test_compute_pub_date_index_zero
    assert_equal 'Thu, 01 Jan 2026 09:00:00 +0900',
                 compute_pub_date('2026-01-01T09:00:00+09:00', 7, 0).rfc2822
  end

  def test_compute_pub_date_advances_by_interval
    assert_equal 'Thu, 15 Jan 2026 09:00:00 +0900',
                 compute_pub_date('2026-01-01T09:00:00+09:00', 7, 2).rfc2822
  end

  # ---- R2 key / URL construction ----

  def test_r2_key_with_prefix
    cfg = { 'r2' => { 'key_prefix' => 'pod/' } }
    assert_equal 'pod/a b.mp3', r2_key(cfg, 'a b.mp3')
  end

  def test_r2_key_without_prefix
    assert_equal 'a b.mp3', r2_key({ 'r2' => {} }, 'a b.mp3')
  end

  def test_r2_public_url_encodes_and_joins
    cfg = { 'r2' => { 'key_prefix' => 'pod/', 'public_base_url' => 'https://ex.com/' } }
    assert_equal 'https://ex.com/pod/a%20b.mp3', r2_public_url(cfg, 'a b.mp3')
  end

  def test_r2_public_url_without_prefix
    cfg = { 'r2' => { 'public_base_url' => 'https://ex.com' } }
    assert_equal 'https://ex.com/a%20b.mp3', r2_public_url(cfg, 'a b.mp3')
  end

  # ---- feed golden test (locks REXML serialization) ----

  def test_append_item_matches_golden_serialization
    doc = load_feed(File.join(FIXTURES, 'feed_min.xml'))
    ensure_itunes_namespace(doc)

    assert_equal ['existing.mp3'], existing_guids(doc).to_a

    pub = Time.parse('2026-02-01T09:00:00+09:00')
    append_item(
      doc,
      title: 'New & Shiny <Episode>',
      description: "Line one\nLine two with [brackets]",
      pub_date: pub,
      guid: 'new episode.mp3',
      mp3_url: 'https://ex.com/new%20episode.mp3',
      mp3_size: 12_345,
      duration_sec: 3661.7
    )

    actual = Dir.mktmpdir do |dir|
      out = File.join(dir, 'feed.xml')
      write_feed(doc, out)
      File.read(out)
    end

    expected = File.read(File.join(FIXTURES, 'feed_after_append.xml'))
    assert_equal expected, actual
  end

  def test_ensure_itunes_namespace_is_idempotent
    doc = load_feed(File.join(FIXTURES, 'feed_min.xml'))
    ensure_itunes_namespace(doc)
    ensure_itunes_namespace(doc)
    assert_equal ITUNES_NS, doc.root.namespaces['itunes']
  end
end
