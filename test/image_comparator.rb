# frozen_string_literal: true

require 'chunky_png'

# Compares images using the Structural Similarity Index Measure (SSIM) algorithm
class ImageComparator
  def compare(img1, img2)
    i1 = ChunkyPNG::Image.from_file(img1)
    i2 = ChunkyPNG::Image.from_file(img2)

    ssim(i1, i2)
  end

  def ssim(i1, i2)
    # Return 0 if image dimensions don't match
    return 0.0 if i1.width != i2.width || i1.height != i2.height

    pixels1 = i1.pixels.map { |p| ChunkyPNG::Color.r(p) } # use only RED
    pixels2 = i2.pixels.map { |p| ChunkyPNG::Color.r(p) }

    m1 = mean(pixels1)
    m2 = mean(pixels2)
    v1 = variance(pixels1, m1)
    v2 = variance(pixels2, m2)
    c12 = covariance(pixels1, pixels2, m1, m2)

    k1 = 0.01
    k2 = 0.03
    l = 255.0
    c1 = (k1 * l)**2
    c2 = (k2 * l)**2

    (((2 * m1 * m2) + c1) * ((2 * c12) + c2)) / (((m1**2) + (m2**2) + c1) * (v1 + v2 + c2))
  end

  private

  def mean(arr)
    arr.sum.to_f / arr.size
  end

  def variance(arr, m)
    arr.sum { |x| (x - m)**2 }.to_f / arr.size
  end

  def covariance(arr1, arr2, m1, m2)
    arr1.zip(arr2).sum { |x, y| (x - m1) * (y - m2) }.to_f / arr1.size
  end
end
