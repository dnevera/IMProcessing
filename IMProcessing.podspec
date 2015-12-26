Pod::Spec.new do |s|

  s.name         = 'IMProcessing'
  s.version      = '0.1.0'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'denn nevera' => 'denn.nevera@gmail.com' }
  s.homepage     = 'http://degradr.photo'
  s.summary      = 'IMProcessing is an image processing framework based on Apple Metal'
  s.description  = 'IMProcessing is an image processing framework provides original effect image/photo. It can be called "masterwork" image processing.'

  s.source       = { :git => 'https://bitbucket.org/degrader/improcessing.git', :tag => '0.1.0'}

  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "8.3"
  s.frameworks   = 'Metal'
  s.requires_arc = true

  s.source_files  = 'IMProcessing/Classes/**/*.{h,swift}', 'IMProcessing/Classes/*.{swift}'
  s.public_header_files = 'IMProcessing/Classes/**/*.h','IMProcessing/Classes/Shaders/*.h'

end