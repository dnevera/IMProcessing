Pod::Spec.new do |s|

  s.name         = 'IMProcessing'
  s.version      = '0.0.1'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'denn nevera' => 'denn.nevera@gmail.com' }
  s.homepage     = 'http://degradr.photo'
  s.summary      = 'IMProcessing is an image processing framework based on Apple Metal'
  s.description  = 'IMProcessing is an image processing framework provides original effect image/photo. It can be called "masterwork" image processing.'

  s.platform     = :osx, '10.11'
  s.source       = { :git => 'https://github.com/dnevera/IMProcessing.git', :tag => '0.0.1'}
  
  s.source_files  = 'IMProcessing/Classes/**/*.{h,swift}'
  s.public_header_files = 'IMProcessing/Classes/**/*.h'

  s.frameworks   = 'UIKit', 'Metal'
  s.requires_arc = true


end