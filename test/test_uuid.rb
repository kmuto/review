#!/usr/bin/env ruby
# encoding: us-ascii
#
# Original license is below:
#
# Copyright(c) 2005 URABE, Shyouhei.
#
# Permission is hereby granted, free of  charge, to any person obtaining a copy
# of  this code, to  deal in  the code  without restriction,  including without
# limitation  the rights  to  use, copy,  modify,  merge, publish,  distribute,
# sublicense, and/or sell copies of the code, and to permit persons to whom the
# code is furnished to do so, subject to the following conditions:
#
#        The above copyright notice and this permission notice shall be
#        included in all copies or substantial portions of the code.
#
# THE  CODE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND, EXPRESS  OR
# IMPLIED,  INCLUDING BUT  NOT LIMITED  TO THE  WARRANTIES  OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE  AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHOR  OR  COPYRIGHT  HOLDER BE  LIABLE  FOR  ANY  CLAIM, DAMAGES  OR  OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF  OR IN CONNECTION WITH  THE CODE OR THE  USE OR OTHER  DEALINGS IN THE
# CODE.

require 'test/unit'
require 'uuid'

class TC_UUID < Test::Unit::TestCase
	def test_v1
		u1 = UUID.create
		u2 = UUID.create
		assert_not_equal u1, u2
	end

	def test_v1_repeatability
		u1 = UUID.create 1, 2, "345678"
		u2 = UUID.create 1, 2, "345678"
		assert_equal u1, u2
	end

	def test_v3
		u1 = UUID.create_md5 "foo", UUID::NameSpace_DNS
		u2 = UUID.create_md5 "foo", UUID::NameSpace_DNS
		u3 = UUID.create_md5 "foo", UUID::NameSpace_URL
		assert_equal u1, u2
		assert_not_equal u1, u3
	end

	def test_v5
		u1 = UUID.create_sha1 "foo", UUID::NameSpace_DNS
		u2 = UUID.create_sha1 "foo", UUID::NameSpace_DNS
		u3 = UUID.create_sha1 "foo", UUID::NameSpace_URL
		assert_equal u1, u2
		assert_not_equal u1, u3
	end

	def test_v4
		# This test  is not  perfect, because the  random nature of  version 4
		# UUID  it is  not always  true that  the three  objects  below really
		# differ.  But  in real  life it's  enough to say  we're OK  when this
		# passes.
		u1 = UUID.create_random
		u2 = UUID.create_random
		u3 = UUID.create_random
		assert_not_equal u1.raw_bytes, u2.raw_bytes
		assert_not_equal u1.raw_bytes, u3.raw_bytes
		assert_not_equal u2.raw_bytes, u3.raw_bytes
	end

	def test_pack
		u1 = UUID.pack 0x6ba7b810, 0x9dad, 0x11d1, 0x80, 0xb4,
		"\000\300O\3240\310"
		assert_equal UUID::NameSpace_DNS, u1
	end

	def test_unpack
		tl, tm, th, cl, ch, m = UUID::NameSpace_DNS.unpack
		assert_equal 0x6ba7b810, tl
		assert_equal 0x9dad, tm
		assert_equal 0x11d1, th
		assert_equal 0x80, cl
		assert_equal 0xb4, ch
		assert_equal "\000\300O\3240\310", m
	end

	def test_parse
		u1 = UUID.pack 0x6ba7b810, 0x9dad, 0x11d1, 0x80, 0xb4,
		"\000\300O\3240\310"
		u2 = UUID.parse "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		u3 = UUID.parse "urn:uuid:6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		assert_equal u1, u2
		assert_equal u1, u3
	end

	def test_to_s
		u1 = UUID.parse "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		assert_equal "6ba7b810-9dad-11d1-80b4-00c04fd430c8", u1.to_s
	end

	def test_to_i
		u1 = UUID.parse "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		assert_equal 0x6ba7b8109dad11d180b400c04fd430c8, u1.to_i
	end

	#def test_time
	#	assert_raises(RangeError) do
	#		UUID::Nil.time
	#	end
	#	0.times do |i|
	#		t = Time.at i, i
	#		u = UUID.create 0, t
	#		assert_equal t.tv_sec, u.time.tv_sec
	#		assert_equal t.tv_usec, u.time.tv_usec
	#	end
	#end

	def test_version
		assert_equal 0, UUID::Nil.version
		assert_equal 1, UUID.create.version
		100.times do # x100 random tests may be enough?
			assert_equal 4, UUID.create_random.version
		end
	end

	def test_clock
		assert_equal 0, UUID::Nil.clock
		1000.times do |i| # clock is 14bit so 8191 suffice, but it's too slow
			u = UUID.create i
			assert_equal i, u.clock
		end
	end

	def test_equality
		u1 = UUID.parse "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		u2 = UUID.parse "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
		assert_equal u1.hash, u2.hash
		case u1
		when u2
			assert_equal true, true # ok
		else
			flunk "u1 != u2"
		end
	end
end



# Local Variables:
# mode: ruby
# coding: utf-8
# indent-tabs-mode: t
# tab-width: 3
# ruby-indent-level: 3
# fill-column: 79
# default-justification: full
# End:
# vi: ts=3 sw=3
