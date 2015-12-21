Pod::Spec.new do |s|

  s.name         = 'DegradrCore3'
  s.version      = '0.7.1'
  s.license      = { :type => 'BSD3', :file => 'LICENSE' }
  s.author       = { 'denn nevera' => 'denn.nevera@gmail.com' }
  s.homepage     = 'http://degradr.photo'
  s.summary      = 'DegradrCore3 is an image processing framework based on Apple Metal'
  s.description  = 'DegradrCore3 is an image processing framework provides original effect image/photo. It can be called "masterwork" image processing.'

  s.platform     = :ios, '8.0'
  s.source       = { :git => 'https://bitbucket.org/degrader/degradr-core-3.git', :tag => '0.7.1'}
  
  s.source_files  = 'DegradrCore3/Classes/*.{h,m}', 'DegradrCore3/Classes/Utils/*.{h,m}', 'DegradrCore3/Classes/Shaders/*.{h}', 'DegradrCore3/Classes/Shaders/DPMTLKit/*.{h}', 'vendor/libjpeg-turbo/include/*'
  s.public_header_files = 'DegradrCore3/Classes/*.h', 'DegradrCore3/Classes/Utils/*.h', 'DegradrCore3/Classes/Shaders/*.h', 'DegradrCore3/Classes/Shaders/DPMTLKit/*.{h}'
  s.vendored_libraries  = 'vendor/libjpeg-turbo/lib/libturbojpeg.a'

  s.frameworks   = 'UIKit', 'Metal'
  s.requires_arc = true
  
  s.dependency "DegradrMath"

end