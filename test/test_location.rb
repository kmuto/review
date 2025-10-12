# frozen_string_literal: true

require_relative 'test_helper'
require 'review/compiler'
require 'stringio'

class LocationTest < Test::Unit::TestCase
  def setup
  end

  def test_lineno
    f = StringIO.new("a\nb\nc\n")
    location = ReVIEW::Location.new('foo', f)
    assert_equal 0, location.lineno
    f.gets
    assert_equal 1, location.lineno
  end

  def test_string
    location = ReVIEW::Location.new('foo', StringIO.new("a\nb\nc\n"))
    assert_equal 'foo:0', location.string
  end

  def test_to_s
    location = ReVIEW::Location.new('foo', StringIO.new("a\nb\nc\n"))
    assert_equal 'foo:0', location.to_s
  end

  def test_to_s_nil
    location = ReVIEW::Location.new('foo', nil)
    assert_equal 'foo:nil', location.to_s
  end

  def test_snapshot
    f = StringIO.new("a\nb\nc\n")
    location = ReVIEW::Location.new('foo', f)
    snapshot = location.snapshot
    assert_instance_of(ReVIEW::SnapshotLocation, snapshot)
    assert_equal 'foo', snapshot.filename
    assert_equal 0, snapshot.lineno
    assert_equal 'foo:0', snapshot.to_s

    f.gets
    assert_equal 1, location.lineno
    # Snapshot should remain unchanged
    assert_equal 0, snapshot.lineno
  end

  def test_snapshot_location_immutable
    snapshot = ReVIEW::SnapshotLocation.new('bar', 42)
    assert_equal 'bar:42', snapshot.string
    assert snapshot.frozen?
  end

  def test_snapshot_location_snapshot
    snapshot = ReVIEW::SnapshotLocation.new('baz', 10)
    snapshot2 = snapshot.snapshot
    assert_same(snapshot, snapshot2)
  end
end
